import Foundation
import DigitalWorldCore

/// File-provider synchronization works with a user-selected iCloud Drive folder without embedding team credentials.
@MainActor
final class CloudBackupCoordinator: ObservableObject {
    struct Revision: Identifiable { let url: URL; let date: Date; var id: String { url.lastPathComponent } }
    @Published var revisions: [Revision] = []
    @Published var busy = false
    @Published var notice = "选择iCloud Drive或其它云盘文件夹，保存不可覆盖的设备合集快照。"
    @Published private(set) var connected = false
    @Published var automatic: Bool { didSet { UserDefaults.standard.set(automatic,forKey: "cloud.backup.automatic") } }
    private var folder: URL?
    private var lastAttempt = Date.distantPast
    private let bookmarkKey = "cloud.backup.folder"
    init() {
        automatic = UserDefaults.standard.object(forKey: "cloud.backup.automatic") as? Bool ?? true
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,options: .withoutUI,bookmarkDataIsStale: &stale) {
                folder = url; connected = true
            }
        }
    }
    func select(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: .minimalBookmark,includingResourceValuesForKeys: nil,relativeTo: nil)
        UserDefaults.standard.set(data,forKey: bookmarkKey); folder = url; connected = true
        notice = "已连接云盘文件夹；其它手机选择同一文件夹即可读取快照。"
        refresh()
    }
    func disconnect() { folder = nil; connected = false; revisions = []; UserDefaults.standard.removeObject(forKey: bookmarkKey) }
    func upload(model: WorldViewModel,force: Bool = true) {
        guard !busy,let folder,let library = model.library,model.state != nil,
              force || (automatic && Date().timeIntervalSince(lastAttempt) >= 900) else { return }
        do { try model.saveCurrentSlot() } catch { notice = error.localizedDescription; return }
        let index = model.libraryIndex
        busy = true; lastAttempt = Date()
        Task {
            do {
                let count = try await Task.detached(priority: .utility) {
                    let archive = try DeviceArchive.capture(index: index,library: library,at: Date())
                    let access = folder.startAccessingSecurityScopedResource(); defer { if access { folder.stopAccessingSecurityScopedResource() } }
                    let url = folder.appendingPathComponent("DigitalWorld-\(Int(archive.createdAt.timeIntervalSince1970))-\(archive.id.uuidString).worldarchive")
                    var coordinationError: NSError?; var writeError: Error?
                    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url,options: [],error: &coordinationError) { coordinated in
                        do { try archive.encode().write(to: coordinated,options: .atomic) } catch { writeError = error }
                    }
                    if let coordinationError { throw coordinationError }
                    if let writeError { throw writeError }
                    return archive.entries.count
                }.value
                notice = "已保存\(count)台设备的云端快照；系统云盘负责上传同步。"
                busy = false; refresh()
            } catch { busy = false; notice = "云端备份失败：\(error.localizedDescription)" }
        }
    }
    func refresh() {
        guard !busy,let folder else { return }; busy = true
        Task {
            do {
                let files = try await Task.detached(priority: .utility) {
                    let access = folder.startAccessingSecurityScopedResource(); defer { if access { folder.stopAccessingSecurityScopedResource() } }
                    return try FileManager.default.contentsOfDirectory(at: folder,includingPropertiesForKeys: [.contentModificationDateKey],options: [])
                        .filter { $0.pathExtension == "worldarchive" || ($0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent.hasSuffix(".worldarchive.icloud")) }
                        .map { url -> URL in
                            if url.lastPathComponent.hasSuffix(".worldarchive.icloud") {
                                return url.deletingLastPathComponent().appendingPathComponent(String(url.lastPathComponent.dropFirst().dropLast(7)))
                            }
                            return url
                        }
                        .map { ($0,(try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
                        .sorted { $0.1 > $1.1 }
                }.value
                revisions = files.map { Revision(url: $0.0,date: $0.1) }; busy = false
            } catch { busy = false; notice = "无法读取云盘：\(error.localizedDescription)" }
        }
    }
    func inspect(_ revision: Revision,library: DeviceLibraryStore) async throws -> DeviceArchive {
        guard let folder else { throw GameError.unavailable("请先连接云盘文件夹") }
        return try await Task.detached(priority: .utility) {
            let access = folder.startAccessingSecurityScopedResource(); defer { if access { folder.stopAccessingSecurityScopedResource() } }
            if (try? revision.url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
                try FileManager.default.startDownloadingUbiquitousItem(at: revision.url)
            }
            var coordinationError: NSError?; var result: Result<Data,Error>?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: revision.url,options: [],error: &coordinationError) { url in
                result = Result {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= DeviceArchive.maximumBytes else { throw GameError.saveCorrupt }
                    return try Data(contentsOf: url)
                }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw GameError.saveCorrupt }
            return try DeviceArchive.decode(result.get(),library: library)
        }.value
    }
}
