import CoreMotion
import DigitalWorldCore
import SwiftUI

@MainActor
final class MotionTrainingController: ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var steps = 0
    @Published private(set) var notice = ""
    private let motion = CMMotionManager()
    private let pedometer = CMPedometer()
    private var input = SensorTrainingInput()
    private var runID: UUID?
    var stepKey = "A"
    var onInput: ((String) -> Void)?

    func start(_ mode: SensorTrainingMode) {
        stop()
        input = SensorTrainingInput()
        count = 0
        steps = 0
        notice = ""
        let id = UUID()
        runID = id
        switch mode {
        case .virtual:
            notice = "使用下方 A/B 按钮。"
        case .shake:
            guard motion.isAccelerometerAvailable else { unavailable(); return }
            notice = "轻摇触发 A/B。每次输入后让手机回到静止。"
            motion.accelerometerUpdateInterval = 1 / 30
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                Task { @MainActor in
                    guard let self, self.runID == id else { return }
                    if let error { self.failed(error); return }
                    guard let data else { return }
                    let a = data.acceleration
                    if let key = self.input.shake(x: a.x, y: a.y, z: a.z, time: data.timestamp) { self.accept(key) }
                }
            }
        case .tilt:
            guard motion.isDeviceMotionAvailable else { unavailable(); return }
            notice = "向左右倾斜触发 A/B，每次需回到中间再倾斜。"
            motion.deviceMotionUpdateInterval = 1 / 30
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                Task { @MainActor in
                    guard let self, self.runID == id else { return }
                    if let error { self.failed(error); return }
                    guard let data else { return }
                    if let key = self.input.tilt(gravityX: data.gravity.x) { self.accept(key) }
                }
            }
        case .walking:
            guard CMPedometer.isStepCountingAvailable(),
                  ![.denied, .restricted].contains(CMPedometer.authorizationStatus()) else { unavailable(); return }
            notice = "每新增 10 个系统实测步数触发一次所选按键。"
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                Task { @MainActor in
                    guard let self, self.runID == id else { return }
                    if let error { self.failed(error); return }
                    guard let count = data?.numberOfSteps.intValue else { return }
                    self.steps = max(self.steps, count)
                    let pulses = self.input.walking(steps: self.steps, key: self.stepKey)
                    for key in pulses where self.runID == id { self.accept(key) }
                }
            }
        }
    }

    func stop() {
        runID = nil
        motion.stopAccelerometerUpdates()
        motion.stopDeviceMotionUpdates()
        pedometer.stopUpdates()
    }

    private func accept(_ choice: String) {
        guard count < 5 else { return }
        count += 1
        onInput?(choice)
        if count == 5 { stop() }
    }

    private func unavailable() {
        stop()
        notice = "该传感器不可用或运动权限未开启。你仍可用虚拟 A/B 按钮。"
    }

    private func failed(_ error: Error) {
        stop()
        notice = error.localizedDescription
    }
}

struct MotionTrainingView: View {
    @ObservedObject var model: WorldViewModel
    @StateObject private var motion = MotionTrainingController()
    @Environment(\.scenePhase) private var phase
    @State private var sessionID: UUID?
    @State private var walkingKey = "A"
    @State private var trainingError: String?

    private var mode: SensorTrainingMode { model.state?.settings.presentation.sensorTrainingMode ?? .virtual }

    var body: some View {
        ScrollView {
            Panel(title: "运动输入训练") {
                Picker("输入模式", selection: Binding(get: { mode }, set: { value in
                    model.editPresentation { $0.sensorTrainingMode = value }
                })) {
                    ForEach(SensorTrainingMode.allCases) { Text(title($0)).tag($0) }
                }.disabled(sessionID != nil)
                if mode == .walking {
                    Picker("步行触发按键", selection: $walkingKey) { Text("A").tag("A"); Text("B").tag("B") }
                        .pickerStyle(.segmented).onChange(of: walkingKey) { _, key in motion.stepKey = key }
                }
                Text("运动模式仅在训练时使用传感器。虚拟按钮可随时替代；本页只读取运动数据。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                if !motion.notice.isEmpty { Text(motion.notice).font(.caption) }
                if let trainingError { Text(trainingError).font(.caption).foregroundStyle(Palette.amber) }
                if mode == .walking { Text("实测步数 \(motion.steps)").accessibilityIdentifier("realTrainingSteps") }
                if sessionID == nil {
                    GameButton(title: "开始运动训练") { begin() }
                        .accessibilityIdentifier("beginSensorTraining")
                        .disabled(model.state?.training != nil)
                } else {
                    Text("\(model.state?.dmc?.trainingChoices.count ?? 0) / 5")
                    HStack {
                        Button("A / 上段") { submit("A") }.accessibilityIdentifier("sensorVirtualA")
                        Button("B / 下段") { submit("B") }.accessibilityIdentifier("sensorVirtualB")
                    }
                    Button("停止并取消") { abandon() }
                }
                if let result = model.trainingScore { Text("\(result) / 5").accessibilityIdentifier("sensorTrainingResult") }
            }.padding()
        }
        .onChange(of: model.state?.training?.id) { _, id in
            if let sessionID, id != sessionID { motion.stop(); self.sessionID = nil }
        }
        .onChange(of: phase) { _, value in if value == .background { abandon() } }
        .onDisappear { abandon() }
    }

    private func begin() {
        guard model.isOriginal, !model.isClassic, model.state?.training == nil else { return }
        trainingError = nil
        model.beginTraining()
        guard let id = model.state?.training?.id else {
            trainingError = model.alert
            model.alert = nil
            return
        }
        sessionID = id
        motion.stepKey = walkingKey
        motion.onInput = { [weak model] key in
            guard let model, model.state?.training?.id == id else { return }
            model.originalTraining(key)
        }
        motion.start(mode)
    }

    private func submit(_ key: String) {
        guard let sessionID, model.state?.training?.id == sessionID else { return }
        model.originalTraining(key)
    }

    private func abandon() {
        motion.stop()
        if let sessionID, model.state?.training?.id == sessionID { model.cancelTraining() }
        sessionID = nil
    }

    private func title(_ mode: SensorTrainingMode) -> String {
        switch mode {
        case .virtual: return "虚拟 A/B"
        case .shake: return "加速度摇晃"
        case .tilt: return "重力倾斜"
        case .walking: return "真实计步"
        }
    }
}
