import SwiftUI
import DigitalWorldCore

struct TrainingView: View {
    @ObservedObject var model: WorldViewModel
    var body: some View {
        if model.isOriginal { original } else { legacy }
    }
    private var original: some View {
        Panel(title: "TRAINING / 上下段攻击") {
            Text("A 攻击上段，B 攻击下段。每组5次，命中至少3次成功；完成整组无论成败都计入训练与努力，取消不计数。")
                .font(.footnote).foregroundStyle(Palette.muted)
            HStack {
                SpriteThumbnail(id: model.state?.pet.speciesID ?? "agumon",size: 88)
                Spacer()
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(Palette.amber)
                SpriteThumbnail(id: model.state?.pet.speciesID ?? "agumon",size: 88).scaleEffect(x: -1,y: 1)
            }
            let hits = model.state?.dmc?.trainingHits ?? []
            HStack {
                ForEach(0..<5,id: \.self) { index in
                    Image(systemName: index < hits.count ? (hits[index] ? "checkmark.circle.fill" : "xmark.circle") : "circle.dotted")
                        .font(.title2).foregroundStyle(index < hits.count && hits[index] ? Palette.mint : Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }.accessibilityLabel("已完成\(hits.count)次攻击，命中\(hits.filter { $0 }.count)次")
            if model.state?.training != nil {
                Text("第 \(hits.count+1) / 5 次攻击").font(.headline)
                HStack {
                    GameButton(title: "A / 上段") { model.originalTraining("A") }.accessibilityIdentifier("training-A")
                    GameButton(title: "B / 下段") { model.originalTraining("B") }.accessibilityIdentifier("training-B")
                }
                Button("结束本次训练") { model.cancelTraining() }
            } else {
                if let score = model.trainingScore {
                    Text("命中 \(score) / 5 · \(score >= 3 ? "成功，力量＋1心" : "失败，训练次数已记录")")
                        .font(.headline).foregroundStyle(Palette.mint)
                }
                GameButton(title: "开始训练") { model.beginTraining() }.accessibilityIdentifier("beginTraining")
            }
            Readout(name: "本阶段训练",value: "\(model.state?.pet.dmc?.stageTrainings ?? 0) 次")
            HeartReadout(name: "努力",value: model.state?.pet.dmc?.effortHearts ?? 0)
        }
    }
    private var legacy: some View {
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
