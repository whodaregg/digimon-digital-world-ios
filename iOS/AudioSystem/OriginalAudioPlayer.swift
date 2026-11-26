import AVFoundation
import DigitalWorldCore
import UIKit

@MainActor
final class OriginalAudioPlayer {
    private struct Track {
        let asset: OriginalAudioAsset
        let player: AVAudioPlayer
    }
    private let manager: OriginalAudioAssetManager
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var tracks: [AudioChannel: Track] = [:]
    private var prepared: [UUID: Track] = [:]
    private var lastEvent: [AudioEvent: TimeInterval] = [:]
    private var context: AudioContext?
    private var musicEvent: AudioEvent = .backgroundMusic
    private var preferences = DeviceAudioPreferences()
    private var active = false
    private var enabled = true
    private var interrupted = false
    private var previewTrack: AVAudioPlayer?
    private var resumeAfterInterrupt = false
    private var cueTask: Task<Void, Never>?
    private var evolutionTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(manager: OriginalAudioAssetManager) {
        self.manager = manager
        let session = AVAudioSession.sharedInstance()
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                  object: session, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in self?.interruption(type, options: options) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification,
                                                                  object: session, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                self.stopPreview()
                self.endEvolution()
                self.tracks.values.forEach { $0.player.pause() }
            }
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func keyFeedback() {
        haptic.impactOccurred(intensity: 0.65)
        haptic.prepare()
    }

    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        if value {
            updateMusic()
        } else {
            stopPreview()
            endEvolution()
            stopAll()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func configure(context newContext: AudioContext, enabled: Bool) {
        let newPreferences = manager.settings(for: newContext.deviceID)
        let changed = newContext != context || newPreferences != preferences || enabled != self.enabled
        if context?.deviceID != newContext.deviceID {
            musicEvent = .backgroundMusic
            endEvolution()
            stopAll()
        }
        context = newContext
        self.enabled = enabled
        preferences = newPreferences
        guard changed else { return }
        if !enabled {
            stopPreview()
            endEvolution()
            stopAll()
        } else {
            updateMusic()
            preload()
        }
    }

    func libraryChanged() {
        prepared.removeAll()
        let valid = Set(manager.manifest.assets.filter { manager.available.contains($0.storageName) }.map(\.id))
        for channel in AudioChannel.allCases {
            guard let track = tracks[channel],
                  !valid.contains(track.asset.id) ||
                    !manager.manifest.assets.contains(where: { $0 == track.asset }) else { continue }
            track.player.stop()
            tracks[channel] = nil
        }
        updateMusic()
        preload()
    }

    func emit(_ event: AudioEvent, override: AudioContext? = nil) {
        guard let current = override ?? context, active, enabled, !interrupted,
              let asset = manager.resolve(event, context: current) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - (lastEvent[event] ?? -1) >= 0.075 else { return }
        if start(asset, priorityCheck: true) { lastEvent[event] = now }
    }

    func battleMusic(_ playing: Bool) {
        musicEvent = playing ? .battleMusic : .backgroundMusic
        updateMusic()
    }

    func careSequence(_ events: [AudioEvent]) {
        cueTask?.cancel()
        guard let context, active, enabled, !interrupted else { return }
        cueTask = Task { @MainActor [weak self] in
            for event in events {
                guard let self, !Task.isCancelled, self.context == context else { return }
                guard let asset = self.manager.resolve(event, context: context) else { continue }
                self.emit(event)
                try? await Task.sleep(for: .seconds(min(0.6, asset.duration)))
            }
        }
    }

    func evolution(_ context: AudioContext) {
        endEvolution()
        guard active, enabled, !interrupted else { return }
        evolutionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if self.manager.resolve(.evolutionTrigger, context: context) != nil {
                self.emit(.evolutionTrigger, override: context)
            } else if let type = context.evolutionType {
                self.emit(type, override: context)
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self.emit(.deviceEvolutionResponse, override: context)
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self.emit(.evolutionMusic, override: context)
            try? await Task.sleep(for: .milliseconds(230))
            guard !Task.isCancelled else { return }
            self.emit(.evolutionVoice, override: context)
            try? await Task.sleep(for: .milliseconds(570))
            guard !Task.isCancelled else { return }
            self.emit(.formReveal, override: context)
            try? await Task.sleep(for: .milliseconds(1650))
            guard !Task.isCancelled else { return }
            self.emit(.evolutionComplete, override: context)
            self.endEvolution(fade: true)
        }
    }

    func preview(_ asset: OriginalAudioAsset) throws {
        stopPreview()
        guard active, !interrupted, manager.available.contains(asset.storageName) else { throw AudioImportError.missingFile }
        let player = try open(asset)
        activateSession()
        player.volume = Float(asset.mapping.volume * preferences.volume(asset.mapping.channel))
        tracks[.bgm]?.player.setVolume(0, fadeDuration: 0.15)
        guard player.play() else { updateDucking(); throw AudioImportError.invalidFile }
        previewTrack = player
        scheduleDucking()
    }

    func stopPreview() {
        previewTrack?.stop()
        previewTrack = nil
        updateDucking()
    }

    private func interruption(_ type: UInt?, options: UInt) {
        if type == AVAudioSession.InterruptionType.began.rawValue {
            resumeAfterInterrupt = tracks[.bgm]?.player.isPlaying == true
            interrupted = true
            stopPreview()
            endEvolution()
            tracks.values.forEach { $0.player.pause() }
        } else if type == AVAudioSession.InterruptionType.ended.rawValue {
            interrupted = false
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            if shouldResume, resumeAfterInterrupt { updateMusic() }
            resumeAfterInterrupt = false
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = preferences.respectSilentSwitch ? .ambient : .playback
        if session.category != category {
            try? session.setCategory(category, mode: .default, options: category == .ambient ? [] : [.mixWithOthers])
        }
        try? session.setActive(true)
    }

    private func open(_ asset: OriginalAudioAsset) throws -> AVAudioPlayer {
        try AVAudioPlayer(contentsOf: manager.file(for: asset),
                          fileTypeHint: asset.format == "aac" ? "public.aac-audio" : nil)
    }

    private func preload() {
        guard let context, active, enabled else { return }
        var next: [UUID: Track] = [:]
        for event in [AudioEvent.keyPress, .menuSelect, .confirm, .cancel, .error, .eatMeat, .eatPill, .attack] {
            guard let asset = manager.resolve(event, context: context) else { continue }
            if let old = prepared[asset.id], old.asset == asset { next[asset.id] = old }
            else if let player = try? open(asset) {
                player.prepareToPlay()
                next[asset.id] = Track(asset: asset, player: player)
            }
        }
        prepared = next
    }

    @discardableResult private func start(_ asset: OriginalAudioAsset, priorityCheck: Bool) -> Bool {
        let channel = asset.mapping.channel
        let level = asset.mapping.volume * preferences.volume(channel)
        guard level > 0 else { return false }
        let previous = tracks[channel]
        if priorityCheck, let previous, previous.player.isPlaying,
           previous.asset.mapping.priority > asset.mapping.priority { return false }
        let player: AVAudioPlayer
        if let track = prepared[asset.id], track.asset == asset { player = track.player }
        else {
            guard let opened = try? open(asset) else { return false }
            player = opened
        }
        if previous?.player !== player {
            if channel == .bgm, let previous { fadeOut(previous.player, duration: 0.2) }
            else { previous?.player.stop() }
        }
        activateSession()
        player.currentTime = 0
        player.numberOfLoops = asset.mapping.loop ? -1 : 0
        player.volume = channel == .bgm || channel == .evolutionMusic ? 0 : Float(level)
        guard player.play() else { return false }
        tracks[channel] = Track(asset: asset, player: player)
        if channel == .evolutionMusic { player.setVolume(Float(level), fadeDuration: 0.2) }
        scheduleDucking()
        return true
    }

    private func fadeOut(_ player: AVAudioPlayer, duration: TimeInterval) {
        player.setVolume(0, fadeDuration: duration)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            player.stop()
        }
    }

    private func updateMusic() {
        guard active, enabled, !interrupted, let context else { return }
        let asset = manager.resolve(musicEvent, context: context)
        if let track = tracks[.bgm], track.asset == asset {
            if !track.player.isPlaying && track.asset.mapping.loop {
                activateSession()
                track.player.play()
            }
            updateDucking()
        } else if let asset, preferences.volume(.bgm) > 0 { start(asset, priorityCheck: false) }
        else if let old = tracks.removeValue(forKey: .bgm) { fadeOut(old.player, duration: 0.2) }
    }

    private func endEvolution(fade: Bool = false) {
        evolutionTask?.cancel()
        evolutionTask = nil
        if let track = tracks.removeValue(forKey: .evolutionMusic) {
            if fade { fadeOut(track.player, duration: 0.2) }
            else { track.player.stop() }
        }
        scheduleDucking()
    }

    private func stopAll() {
        cueTask?.cancel()
        cueTask = nil
        tracks.values.forEach { $0.player.stop() }
        tracks.removeAll()
        restoreTask?.cancel()
    }

    private func updateDucking() {
        guard let bgm = tracks[.bgm] else { return }
        let duck = [AudioChannel.sfx, .battle, .voice, .evolutionMusic].contains { tracks[$0]?.player.isPlaying == true }
        let musicPlaying = tracks[.evolutionMusic]?.player.isPlaying == true
        let factor = previewTrack?.isPlaying == true || musicPlaying ? 0 : duck ? 0.2 : 1.0
        bgm.player.setVolume(Float(bgm.asset.mapping.volume * preferences.volume(.bgm) * factor), fadeDuration: 0.18)
    }

    private func scheduleDucking() {
        restoreTask?.cancel()
        updateDucking()
        let players = [AudioChannel.sfx, .battle, .voice, .evolutionMusic].compactMap { tracks[$0]?.player } + [previewTrack].compactMap { $0 }
        let delay = players.filter(\.isPlaying).map { max(0, $0.duration - $0.currentTime) }.max() ?? 0
        guard delay > 0 else { return }
        restoreTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay + 0.03))
            guard !Task.isCancelled else { return }
            self?.updateDucking()
        }
    }
}
