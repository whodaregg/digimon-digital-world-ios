import SwiftUI
import UniformTypeIdentifiers
import DigitalWorldCore

struct CloudBackupView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @ObservedObject private var cloud: CloudBackupCoordinator
    init(model: WorldViewModel) { self.model = model; self.cloud = model.cloud }
    @State private var picker = false
    @State private var candidate: DeviceArchive?
    var body: some View {
        Panel(title: "云端备份与同步") {
            Text(l(cloud.notice)).accessibilityIdentifier("cloudNotice")
            Button(l("选择iCloud Drive或云盘文件夹")) { picker = true }.disabled(cloud.busy).accessibilityIdentifier("cloudChooseFolder")
            if cloud.connected {
                Toggle(l("自动保存云端快照"),isOn: $cloud.automatic)
                Button(l("立即备份全部设备")) { cloud.upload(model: model) }.disabled(cloud.busy).accessibilityIdentifier("cloudUpload")
                Button(l("刷新云端快照")) { cloud.refresh() }.disabled(cloud.busy)
                ForEach(cloud.revisions.prefix(30)) { revision in
                    Button {
                        Task {
                            do { if let library = model.library { candidate = try await cloud.inspect(revision,library: library) } }
                            catch { model.alert = error.localizedDescription }
                        }
                    } label: {
                        VStack(alignment: .leading) { Text(l(revision.date.formatted(date: .abbreviated,time: .shortened))); Text(l(revision.id)).font(.caption2).lineLimit(1) }
                    }.disabled(cloud.busy)
                }
                Button(l("断开云盘文件夹")) { cloud.disconnect() }.disabled(cloud.busy)
            }
            Text(l("每次备份生成独立版本，不覆盖另一台手机的进度。恢复先验证全部设备，再作为新设备导入，当前设备保持保留；请选择需要继续养成的版本，避免同时操作同一伙伴。"))
                .font(.caption).foregroundStyle(Palette.muted)
        }.fileImporter(isPresented: $picker,allowedContentTypes: [.folder]) { result in
            do { try cloud.select(result.get()) } catch { model.alert = error.localizedDescription }
        }.confirmationDialog(l("恢复云端设备合集？"),isPresented: Binding(get: { candidate != nil },set: { if !$0 { candidate = nil } }),titleVisibility: .visible) {
            Button(l("作为独立设备恢复")) {
                if let candidate { model.restoreArchive(candidate) }; candidate = nil
            }
            Button(l("取消"),role: .cancel) { candidate = nil }
        } message: { if let candidate { Text(l("此快照包含\(candidate.entries.count)台设备。当前进度不会被覆盖。")) } }
    }
}
