import SwiftUI
import SpriteKit
import DigitalWorldCore

struct ConnectionView: View {
    @ObservedObject var model: WorldViewModel
    @StateObject private var connection = ConnectionCoordinator()
    @State private var scene = QuestBattleScene(size: CGSize(width: 320,height: 240))
    @State private var playedID: UUID?
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        Panel(title: "CONNECTION / 手机连接") {
            Text("双方打开附近连接、互相接受邀请，再分别确认对战。正式养成只能与正式养成连接，Sandbox只能与Sandbox连接。")
                .font(.footnote).foregroundStyle(Palette.muted)
            Text(connection.notice).accessibilityIdentifier("connectionNotice")
            if connection.outcome != nil && playedID != nil {
                SpriteView(scene: scene,preferredFramesPerSecond: 30).aspectRatio(4/3,contentMode: .fit)
                if finished {
                    Text(connection.outcome?.playerWon == true ? model.text(.victory) : model.text(.defeat)).font(.title.bold())
                    Button("准备下一场") { scene.stop(); connection.reset(); playedID = nil; finished = false }
                }
            } else if connection.connected,let remote = connection.remote {
                Text((try? model.database?.species(remote.speciesID).localizedName(model.language)) ?? remote.speciesID)
                GameButton(title: connection.ready ? "等待对方确认" : "确认对战") { connection.confirmBattle() }.disabled(connection.ready)
            } else {
                GameButton(title: "搜索附近玩家") { prepare(online: false) }.accessibilityIdentifier("searchNearby")
                ForEach(connection.peers,id: \.self) { peer in Button("邀请 "+peer.displayName) { connection.invite(peer) } }
                if Bundle.main.object(forInfoDictionaryKey: "GameCenterEnabled") as? Bool == true {
                    Button("Game Center 在线匹配") { prepare(online: true) }
                } else { Text("在线匹配需配置Game Center开发团队能力；本构建尚未启用。") .font(.caption).foregroundStyle(Palette.muted) }
            }
            if let peer = connection.invitation {
                Text("\(peer.displayName) 邀请你连接")
                HStack { Button("接受") { connection.answerInvitation(true) }; Button("拒绝") { connection.answerInvitation(false) } }
            }
            Button("断开连接") { scene.stop(); connection.reset(); playedID = nil; finished = false }
            Text("这是iPhone之间的连接，不代表可以直接连接实体暴龙机。附近双机与Game Center实机联调仍需完成。")
                .font(.caption).foregroundStyle(Palette.muted)
        }.onChange(of: connection.outcome?.id) { _,_ in playResult() }
            .onDisappear { scene.stop(); connection.stop() }
    }
    private func prepare(online: Bool) {
        guard let state = model.state,let database = model.database else { return }
        do {
            connection.stop()
            let fighter = try ConnectionEngine.fighter(for: state,database: database)
            connection.prepare(fighter,database: database)
            if online {
                if let presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController {
                    var top = presenter; while let presented = top.presentedViewController { top = presented }
                    connection.startOnline(from: top)
                }
            } else { connection.searchNearby() }
        } catch { connection.notice = error.localizedDescription }
    }
    private func playResult() {
        guard let result = connection.outcome,result.id != playedID,let player = connection.local,let remote = connection.remote,
              let database = model.database else { return }
        guard model.saveConnection(result,player: player,opponent: remote) else { connection.notice = model.alert ?? "无法保存战果"; return }
        do {
            scene.onFinished = { finished = true }
            scene.playConnection(player: try database.species(player.speciesID),opponent: try database.species(remote.speciesID),result: result,mode: model.display,reduceMotion: reduced)
            playedID = result.id
        } catch { connection.notice = error.localizedDescription }
    }
}
