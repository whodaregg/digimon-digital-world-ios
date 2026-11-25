import SwiftUI
import DigitalWorldCore

struct TrainingView: View {
    @ObservedObject var model: WorldViewModel
    var body: some View {
        Panel(title: "TIMING / 精准训练") {
            Text("在光标进入绿色目标区时按下确认。共 3 次，平均准确度达到 60 分才算训练成功。每次开始消耗 5 能量。")
                .font(.subheadline).foregroundStyle(Palette.muted)
            if let session = model.state?.training {
                Text("\(session.taps.count + 1) / 3").font(.system(size: 40,weight: .black,design: .monospaced)).foregroundStyle(Palette.mint)
                TimelineView(.animation(minimumInterval: 1/30)) { context in
                    let elapsed = context.date.timeIntervalSince(session.startedAt)
                    let position = TrainingEngine.position(elapsed: elapsed)
                    VStack(spacing: 20) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Palette.line)
                                Rectangle().fill(Palette.mint.opacity(0.35)).frame(width: proxy.size.width * 0.16)
                                    .offset(x: proxy.size.width * (TrainingEngine.target-0.08))
                                Rectangle().fill(Palette.mint).frame(width: 4).offset(x: (proxy.size.width-4)*position)
                            }
                        }.frame(height: 50)
                        Text("剩余 \(max(0,15-Int(elapsed))) 秒").font(.system(.caption,design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                }
                GameButton(title: "B / 确认时机") { model.tapTraining() }.accessibilityIdentifier("trainingTap")
                Button("结束本次训练") { model.cancelTraining() }
            } else {
                if let score = model.trainingScore {
                    Text("\(score)").font(.system(size: 70,weight: .black,design: .monospaced)).foregroundStyle(score >= 60 ? Palette.mint : Palette.amber)
                    Text(score >= 60 ? "训练成功 · 力量与亲密度提升" : "时机尚需练习 · 本次尝试已记录").font(.subheadline)
                }
                GameButton(title: "开始训练") { model.beginTraining() }.accessibilityIdentifier("beginTraining")
            }
            if model.state?.pet.isEgg == true { Text("请等待数码蛋孵化。").font(.caption).foregroundStyle(Palette.amber) }
            PetScreen(model: model).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
