import CoreMotion
import SwiftUI
import DigitalWorldCore

@MainActor
final class MotionTrainingController: ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var running = false
    @Published private(set) var notice = ""
    private let manager = CMMotionManager()
    private var counter = MotionInputCounter()
    var onInput: ((String) -> Void)?
    func start() {
        guard manager.isAccelerometerAvailable else { notice = "当前设备无加速度传感器，请使用A/B辅助按钮"; return }
        counter = MotionInputCounter(); count = 0; running = true; notice = "摇晃触发一次输入，方向对应A/B；完成五次后自动停止"
        manager.accelerometerUpdateInterval = 1/30
        manager.startAccelerometerUpdates(to: .main) { [weak self] data,error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.notice = error.localizedDescription; self.stop(); return }
                guard self.running,let data else { return }
                let a = data.acceleration
                if self.counter.sample(x: a.x,y: a.y,z: a.z,time: data.timestamp) {
                    self.count = self.counter.count; self.onInput?(a.x >= 0 ? "A" : "B")
                }
            }
        }
    }
    func stop() { manager.stopAccelerometerUpdates(); running = false }
}
struct MotionTrainingView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @StateObject private var motion = MotionTrainingController()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Panel(title: "SANDBOX / 摇晃输入测试") {
            Text(l("这是手机加速度输入辅助，不是已完成的Pendulum机型规则。仅用于独立Sandbox；A/B按钮可代替摇晃。"))
                .font(.footnote).foregroundStyle(Palette.muted)
            Text(l(motion.notice)).font(.caption)
            Text(l("\(model.state?.dmc?.trainingChoices.count ?? 0) / 5 · \(motion.count) SHAKES")).font(.headline)
            if model.state?.training == nil {
                GameButton(title: "开始摇晃测试") {
                    guard model.isSandbox else { return }
                    model.beginTraining()
                    guard model.state?.training != nil else { return }
                    motion.onInput = { key in if model.isSandbox && model.state?.training != nil { model.originalTraining(key) } }
                    motion.start()
                }
            } else {
                HStack { Button(l("A / 上段")) { model.originalTraining("A") }; Button(l("B / 下段")) { model.originalTraining("B") } }
                Button(l("停止并取消")) { motion.stop(); model.cancelTraining() }
            }
            if let result = model.trainingScore { Text(l("\(result)/5 · \(result >= 3 ? "SUCCESS" : "FAIL")")) }
        }.onChange(of: model.state?.training?.id) { _,id in if id == nil { motion.stop() } }
            .onChange(of: phase) { _,value in if value != .active { motion.stop() } }
            .onDisappear { motion.stop(); if model.state?.training != nil { model.cancelTraining() } }
    }
}
