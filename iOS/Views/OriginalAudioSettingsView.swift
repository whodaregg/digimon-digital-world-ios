import DigitalWorldCore
import SwiftUI
import UniformTypeIdentifiers

struct OriginalAudioSettingsView: View {
    @ObservedObject var assets: OriginalAudioAssetManager
    let model: WorldViewModel
    let deviceID: String
    @State private var showingLibrary = false
    @State private var playbackNotice: String?

    var body: some View {
        Panel(title: "原版音频") {
            Toggle("播放游戏音频", isOn: Binding(get: { model.state?.settings.sound ?? true },
                                               set: { enabled in model.settings { $0.sound = enabled } }))
            Picker("当前机型音频模式", selection: preference(\.mode)) {
                ForEach(AudioMode.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("originalAudioMode")
            Picker("动漫世代", selection: preference(\.series)) {
                Text("未指定").tag(AudioSeries?.none)
                ForEach(AudioSeries.allCases) { Text($0.title).tag(Optional($0)) }
            }
            Toggle("遵循 iPhone 静音模式", isOn: preference(\.respectSilentSwitch))
            Toggle("混合模式使用社区原机录音", isOn: Binding(
                get: { assets.settings(for: deviceID).communityRecordings ?? true },
                set: { enabled in update { $0.communityRecordings = enabled } }))
                .accessibilityIdentifier("useCommunityRecordings")
            Text("已内置 \(assets.communityAssetCount) 份社区录音。逐文件机型待核对，混合模式下用于缺失的操作音效。")
                .font(.caption).foregroundStyle(Palette.muted)
            Button("试听社区按键录音") {
                do {
                    guard let asset = assets.communityAsset(for: .keyPress) else { throw AudioImportError.missingFile }
                    try model.audio.preview(asset)
                    playbackNotice = "已开始播放社区按键录音。若听不到，请检查系统音量、静音开关和蓝牙输出。"
                } catch { playbackNotice = "播放失败：\(error.localizedDescription)" }
            }.accessibilityIdentifier("previewCommunityAudio")
            if let playbackNotice { Text(playbackNotice).font(.caption).accessibilityIdentifier("communityAudioPlaybackStatus") }

            ForEach(AudioChannel.allCases) { channel in
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.volumeTitle).font(.caption)
                    Slider(value: Binding(get: { assets.settings(for: deviceID).volume(channel) },
                                          set: { value in update { $0.volumes[channel] = value } }), in: 0...1)
                        .accessibilityLabel(channel.volumeTitle)
                }
            }
            Button("管理音频资源") { showingLibrary = true }
                .accessibilityIdentifier("originalAudioLibrary")
            Text("有匹配的自有资源时优先播放。社区录音来源见资源库，经典与动漫模式按原有匹配规则播放。").font(.caption).foregroundStyle(Palette.muted)
        }
        .sheet(isPresented: $showingLibrary, onDismiss: { model.audio.stopPreview() }) {
            NavigationStack {
                AudioLibraryView(assets: assets, model: model, deviceID: deviceID)
                    .navigationTitle("音频资源库")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("完成") { showingLibrary = false } }
                    }
            }
        }
    }

    private func preference<T>(_ path: WritableKeyPath<DeviceAudioPreferences, T>) -> Binding<T> {
        Binding(get: { assets.settings(for: deviceID)[keyPath: path] },
                set: { value in update { $0[keyPath: path] = value } })
    }

    private func update(_ edit: (inout DeviceAudioPreferences) -> Void) {
        assets.update(deviceID, edit)
        model.syncAudio()
    }
}

private struct AudioLibraryView: View {
    @ObservedObject var assets: OriginalAudioAssetManager
    let model: WorldViewModel
    let deviceID: String
    @State private var event: AudioEvent = .keyPress
    @State private var category: AudioCategory = .deviceSFX
    @State private var source = ""
    @State private var authorization = ""
    @State private var permitted = false
    @State private var looping = false
    @State private var species = ""
    @State private var stage = ""
    @State private var evolutionType: AudioEvent?
    @State private var priority = 0
    @State private var level = 1.0
    @State private var series: AudioSeries = .adventure
    @State private var importing = false
    @State private var zip = false
    @State private var replacing: OriginalAudioAsset?
    @State private var status = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section("当前事件") {
                Picker("Audio Event ID", selection: $event) {
                    ForEach(AudioEvent.allCases) { Text($0.rawValue).tag($0) }
                }.accessibilityIdentifier("originalAudioEvent")
                if let context = model.audioContext(), let asset = assets.resolve(event, context: context) {
                    if asset.mapping.category == .communityRecording {
                        Text("Missing Original Asset").accessibilityIdentifier("missingOriginalAudio")
                        Text("当前使用社区录音 · \(asset.originalFilename)")
                    } else { Text(asset.originalFilename) }
                } else {
                    Text("Missing Original Asset").accessibilityIdentifier("missingOriginalAudio")
                }
            }
            Section("内置社区录音") {
                Text("原始WAV来自DVPet社区归档。历史资料注明PenOG／DMOG录音贡献者为BladeSabre，逐文件对应机型尚待核对。")
                    .font(.footnote)
                Link("录音归档与固定版本", destination: URL(string: "https://github.com/joeltco/tuipet/tree/b4e3621a55f5906fc7a55107cce3eb7faaf5a60c/src/tuipet/data/sounds")!)
            }
            Section("从 iOS Files 导入") {
                Toggle("我拥有对导入音频的相应使用权限", isOn: $permitted)
                Button("导入 ZIP 音频包") { replacing = nil; zip = true; importing = true }.disabled(!permitted || busy)
                Picker("类别", selection: $category) {
                    ForEach(AudioCategory.allCases.filter { $0 != .communityRecording }) { Text($0.rawValue).tag($0) }
                }
                if isDeviceCategory { LabeledContent("机型", value: deviceID) }
                else {
                    Picker("动漫世代", selection: $series) {
                        ForEach(AudioSeries.allCases) { Text($0.title).tag($0) }
                    }
                }
                TextField("来源", text: $source)
                TextField("授权说明", text: $authorization)
                DisclosureGroup("角色、进化与播放条件") {
                    TextField("数码兽 ID（可选）", text: $species).textInputAutocapitalization(.never)
                    TextField("阶段 ID（可选）", text: $stage).textInputAutocapitalization(.never)
                    Picker("进化类型", selection: $evolutionType) {
                        Text("任意").tag(AudioEvent?.none)
                        ForEach(AudioEvent.evolutionTypes) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    Stepper("优先级 \(priority)", value: $priority, in: 0...100)
                    Slider(value: $level, in: 0...1).accessibilityLabel("资源音量")
                    if channel == .bgm { Toggle("循环播放", isOn: $looping) }
                }
                Button("导入单个音频文件") { replacing = nil; zip = false; importing = true }
                    .disabled(!permitted || !mapping.isValid || busy)
            }
            Section("资源完整性") {
                Button("扫描缺失文件与 SHA-256") {
                    assets.scan()
                    model.audio.libraryChanged()
                    let missing = assets.manifest.assets.filter { !assets.available.contains($0.storageName) }.count
                    status = "已扫描 \(assets.manifest.assets.count) 条资源，\(missing) 条缺失或校验失败。"
                }.disabled(busy)
                if let error = assets.loadingError { Text(error).foregroundStyle(.orange) }
                if !status.isEmpty { Text(status).accessibilityIdentifier("originalAudioStatus") }
                if busy { ProgressView() }
                ForEach(assets.manifest.assets.filter { $0.mapping.event == event }) { asset in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(asset.originalFilename)
                        Text("\(asset.mapping.category.rawValue) · \(asset.duration, specifier: "%.2f") s")
                        Text(asset.mapping.source).font(.caption)
                        Text(asset.mapping.authorization).font(.caption)
                        if !assets.available.contains(asset.storageName) { Text("Missing Original Asset") }
                        Menu("资源操作") {
                            Button("试听") { run { try model.audio.preview(asset) } }
                            Button("停止试听") { model.audio.stopPreview() }
                            Button("替换文件") { replacing = asset; zip = false; importing = true }.disabled(!permitted || busy)
                            Button("移除映射", role: .destructive) {
                                run { try assets.remove(asset.id); model.audio.libraryChanged() }
                            }.disabled(busy)
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: zip ? [.zip] : [.audio]) { result in
            run {
                let url = try result.get()
                let target = replacing
                let importMapping = target?.mapping ?? mapping
                replacing = nil
                if zip {
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do { finish(try await assets.importPack(url)) }
                        catch { status = error.localizedDescription }
                    }
                } else {
                    finish(try assets.selectedFile(url, mapping: importMapping, replacing: target?.id))
                }
            }
        }
    }

    private var channel: AudioChannel {
        if event == .backgroundMusic || event == .battleMusic { return .bgm }
        if event == .evolutionMusic { return .evolutionMusic }
        if category == .characterVoice || event == .evolutionVoice { return .voice }
        return event.battleCue ? .battle : .sfx
    }
    private var isDeviceCategory: Bool { category == .deviceSFX || category == .limitedEdition }
    private var mapping: AudioMapping {
        var value = AudioMapping(event: event, category: category, source: source, authorization: authorization, channel: channel)
        value.deviceID = isDeviceCategory ? deviceID : nil
        value.series = isDeviceCategory ? nil : series
        value.speciesID = species.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        value.stage = stage.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        value.evolutionType = evolutionType
        value.loop = channel == .bgm && looping
        value.priority = priority
        value.volume = level
        return value
    }
    private func run(_ operation: () throws -> Void) {
        do { try operation() }
        catch { status = error.localizedDescription }
    }
    private func finish(_ duplicates: Int) {
        status = duplicates == 0 ? "导入成功。" : "导入成功。检测到 \(duplicates) 个重复文件，已共享资源副本。"
        model.audio.libraryChanged()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
private extension AudioChannel {
    var volumeTitle: String {
        switch self {
        case .bgm: return "BGM 背景音乐"
        case .sfx: return "SFX 操作音效"
        case .voice: return "Voice 语音"
        case .evolutionMusic: return "Evolution Music 进化音乐"
        case .battle: return "战斗音效"
        }
    }
}
private extension AudioSeries {
    var title: String {
        switch self {
        case .adventure: return "Digimon Adventure"
        case .adventure02: return "Digimon Adventure 02"
        case .tamers: return "Digimon Tamers"
        case .frontier: return "Digimon Frontier"
        case .savers: return "Digimon Savers"
        case .xrosWars: return "Digimon Xros Wars"
        }
    }
}
