import DigitalWorldCore
import SwiftUI

struct ArchiveRosterView: View {
    @ObservedObject var model: WorldViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var notice: String?

    private var roster: [Species] {
        (model.database?.species ?? []).filter {
            $0.devices.contains(ArchiveCareEngine.deviceID) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("数码兽图集养成").font(.title2.bold())
                Text("选择伙伴后创建独立养成档案，可喂食、清洁、治疗、休息、训练和对战。上传图集的阶段与进化路线待补充。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                TextField("搜索数码兽原文件名", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("archiveSearch")
                Text("\(roster.count) / 844").accessibilityIdentifier("archiveRosterCount")
                if let notice { Text(notice).foregroundStyle(Palette.amber) }
                ForEach(roster) { species in
                    HStack {
                        SpriteThumbnail(id: species.spriteID)
                        Text(species.name).font(.subheadline)
                        Spacer()
                        Button("开始养成") {
                            if model.adoptArchive(species.id) { dismiss() }
                            else { notice = model.alert; model.alert = nil }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("adopt-\(species.id)")
                    }.padding(.vertical, 4)
                }
            }.padding()
        }
        .background(Palette.background)
        .navigationTitle("选择数码兽")
        .navigationBarTitleDisplayMode(.inline)
    }
}
