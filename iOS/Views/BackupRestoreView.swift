import SwiftUI
import UniformTypeIdentifiers
import DigitalWorldCore

struct BackupRestoreView: View {
    @ObservedObject var model: WorldViewModel
    @State private var picker = false
    @State private var candidate: GameState?
    @State private var confirm = false
    var body: some View {
        Button("从备份文件恢复") { picker = true }
            .fileImporter(isPresented: $picker,allowedContentTypes: [.json]) { result in
                do {
                    candidate = try model.inspectBackup(result.get()); confirm = true
                } catch { model.alert = error.localizedDescription }
            }
            .confirmationDialog("恢复已验证的备份？",isPresented: $confirm,titleVisibility: .visible) {
                Button("恢复此备份") {
                    if let candidate { model.restoreBackup(candidate) }
                    candidate = nil
                }
                Button("取消",role: .cancel) { candidate = nil }
            } message: {
                if let candidate {
                    Text("伙伴：\(candidate.pet.speciesID)\n存档时间：\(candidate.highWatermark.formatted(date: .abbreviated,time: .shortened))\n当前进度会先保存为独立备份。恢复后将结算离线经过的时间。")
                }
            }
    }
}
