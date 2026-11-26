import SwiftUI
import DigitalWorldCore

struct DeviceCollectionView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @State private var selected: DeviceRule?
    var body: some View {
        Group {
        if let database = model.database {
            Panel(title: model.text(.devices)) {
                Text(l("每台设备独立保存；切换时结算对应档案的离线成长。Sandbox与正式收藏隔离。"))
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(model.libraryIndex.slots) { slot in
                    HStack {
                        VStack(alignment: .leading,spacing: 4) {
                            Text(l(database.devices.first(where: { $0.id == slot.deviceID })?.name ?? slot.deviceID)).font(.headline)
                            Text(l(DeviceText(rawValue: slot.style.rawValue)?.text(model.language) ?? slot.style.rawValue))
                                .font(.caption).foregroundStyle(slot.style.isFormal ? Palette.mint : Palette.amber)
                        }
                        Spacer()
                        if slot.id == model.libraryIndex.activeID { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint) }
                        else { Button(l("切换")) { model.activateSlot(slot.id) }.accessibilityIdentifier("switch-slot-\(slot.id.uuidString)") }
                    }.padding(.vertical,6)
                }
            }
            Panel(title: "DEVICE PROFILES") {
                ForEach(database.devices) { profile in
                    Button { selected = profile } label: {
                        HStack {
                            VStack(alignment: .leading,spacing: 4) {
                                Text(l(profile.name)).font(.headline)
                                Text(l(profile.enabled && profile.verifiedOriginal ? model.text(.ready) : profile.enabled ? "旧版实验档兼容" : model.text(.pending)))
                                    .font(.caption).foregroundStyle(profile.enabled && profile.verifiedOriginal ? Palette.mint : Palette.amber)
                            }
                            Spacer(); Image(systemName: "chevron.right")
                        }.padding(.vertical,6).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("profile-\(profile.id)")
                }
            }
        }
        }.sheet(item: $selected) { profile in
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        Panel(title: profile.name) {
                            Text(l(profile.notes)).font(.subheadline)
                            if profile.enabled && profile.verifiedOriginal {
                                Text(l("四心养成 · A/B上下段训练 · 8区顺序Quest · Cold · 一只备份"))
                                Text(l("17种养成角色及最终区Alter-S。附近手机通信已接入；联展和其他版本名单尚待接入。"))
                                    .font(.caption).foregroundStyle(Palette.muted)
                                GameButton(title: "新增独立设备") { model.createDevice(profile.id); selected = nil }
                                    .accessibilityIdentifier("create-device-\(profile.id)")
                            } else {
                                Text(l("缺少逐型号核验的规则、角色名单、训练/战斗参数或原版素材，尚不能创建正式养成。目录不代表已实现该型号。"))
                                    .font(.footnote).foregroundStyle(Palette.amber)
                            }
                        }
                    }.pageStyle()
                }.background(Palette.background).navigationTitle(l(model.text(.device))).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(l("完成")) { selected = nil } } }
            }
        }
    }
}
struct PlaySettingsView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @State private var confirmReset = false
    @State private var minutes = 60
    @State private var showMotion = false
    var body: some View {
        Group {
        if let state = model.state {
            Panel(title: model.text(.mode)) {
                ForEach(PlayStyle.allCases,id: \.self) { style in
                    Button { model.setPlayStyle(style) } label: {
                        HStack { Text(l(DeviceText(rawValue: style.rawValue)?.text(model.language) ?? style.rawValue)); Spacer(); Image(systemName: state.playStyle == style ? "checkmark.circle.fill" : "circle") }
                            .contentShape(Rectangle()).padding(.vertical,6)
                    }.buttonStyle(.plain).accessibilityIdentifier("play-style-\(style.rawValue)")
                }
                Text(l(model.isClassic ? "经典模式仅使用A/B/C进行LCD养成，不公开隐藏进化条件或照顾失误。" : model.isSandbox ? "独立测试副本：角色、数值与时间修改不计入正式收藏。" : "增强模式沿用Ver.1养成规则，增加触屏、图鉴与历史辅助。"))
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            Panel(title: "LCD / INPUT") {
                Toggle(l(model.text(.touch)),isOn: Binding(get: { state.settings.presentation.touchMode },set: { value in model.editPresentation { $0.touchMode = value } }))
                    .disabled(model.isClassic).accessibilityIdentifier("touchMode")
                Text(l("A选择 · B确认 · C返回；C长按2秒打开LCD设置，A＋C切换音效，死亡时A＋B重新孵化。按键支持多指组合与防重复触发。"))
                    .font(.caption).foregroundStyle(Palette.muted)
                Text(l(model.text(.volume)))
                Slider(value: Binding(get: { state.settings.presentation.volume },set: { value in model.editPresentation { $0.volume = value } }),in: 0...1)
                Text(l(model.text(.contrast)))
                Slider(value: Binding(get: { state.settings.presentation.contrast },set: { value in model.editPresentation { $0.contrast = value } }),in: 0.5...1.5)
                Text(l(model.text(.brightness)))
                Slider(value: Binding(get: { state.settings.presentation.brightness },set: { value in model.editPresentation { $0.brightness = value } }),in: 0.3...1)
                Picker(l(model.text(.shell)),selection: Binding(get: { state.settings.presentation.shell },set: { value in model.editPresentation { $0.shell = value } })) {
                    Text(l("Brown")).tag("brown"); Text(l("Gray")).tag("gray"); Text(l("Blue")).tag("blue"); Text(l("White")).tag("white")
                }
                Picker(l(model.text(.language)),selection: Binding(get: { state.settings.presentation.language },set: { value in model.editPresentation { $0.language = value } })) {
                    ForEach(AppLanguage.allCases,id: \.self) { language in Text(l(language.title)).tag(language) }
                }.accessibilityIdentifier("appLanguage")
            }
            if model.isSandbox {
                Panel(title: "SANDBOX") {
                    Stepper(l("\(minutes) MIN"),value: $minutes,in: 1...43_200,step: 10)
                    Button(l(model.text(.timeAdvance))) { model.advanceSandbox(minutes: minutes) }.accessibilityIdentifier("sandboxAdvance")
                    Button(l("摇晃训练输入测试")) { showMotion = true }
                    Button(l(model.text(.returnFormal))) { model.returnToFormal() }.accessibilityIdentifier("returnFormal")
                    Text(l("隐藏开发入口提供角色、道具与数值编辑；这里的时间推进调用同一养成引擎，不改变系统时钟。"))
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
            Panel(title: "RESET") {
                Button(l(model.text(.reset)),role: .destructive) { confirmReset = true }.accessibilityIdentifier("resetDevice")
                Text(l("重置前会另存完整快照，并保留已解锁图鉴。确认后当前设备重新孵化，其他设备不受影响。"))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        }.sheet(isPresented: $showMotion) {
            NavigationStack { MotionTrainingView(model: model).padding().background(Palette.background).navigationTitle(l("Sandbox"))
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(l("完成")) { showMotion = false } } } }
        }
        .confirmationDialog(l("确认重置当前设备？"),isPresented: $confirmReset,titleVisibility: .visible) {
            Button(l("确认重置"),role: .destructive) { model.resetCurrentDevice() }
            Button(l("取消"),role: .cancel) {}
        }
    }
}
