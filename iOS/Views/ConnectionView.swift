import SwiftUI
import SpriteKit
import DigitalWorldCore

struct ConnectionView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @StateObject private var connection = ConnectionCoordinator()
    @State private var scene = QuestBattleScene(size: CGSize(width: 320,height: 240))
    @State private var playedID: UUID?
    @State private var finished = false
    @AppStorage("connection.relayURL") private var serverURL = ""
    @State private var roomCode = ""
    @FocusState private var focused: String?
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        Panel(title: "CONNECTION / 手机连接") {
            Text(l("双方打开附近连接、互相接受邀请，再分别确认对战。正式养成只能与正式养成连接，Sandbox只能与Sandbox连接。"))
                .font(.footnote).foregroundStyle(Palette.muted)
            Text(l(connection.notice)).accessibilityIdentifier("connectionNotice")
            if connection.outcome != nil && playedID != nil {
                SpriteView(scene: scene,preferredFramesPerSecond: 30).aspectRatio(4/3,contentMode: .fit).accessibilityIdentifier("connectionArena")
                if finished {
                    Text(l(connection.outcome?.playerWon == true ? model.text(.victory) : model.text(.defeat))).font(.title.bold())
                    Button(l("准备下一场")) { scene.stop(); model.audio.battleMusic(false); connection.reset(); playedID = nil; finished = false }
                }
            } else if connection.connected,let remote = connection.remote {
                Text(l((try? model.database?.species(remote.speciesID).localizedName(model.language)) ?? remote.speciesID))
                GameButton(title: connection.ready ? "等待对方确认" : "确认对战") { connection.confirmBattle() }.disabled(connection.ready).accessibilityIdentifier("confirmConnection")
            } else {
                GameButton(title: "搜索附近玩家") { prepare(online: false) }.accessibilityIdentifier("searchNearby")
                ForEach(connection.peers,id: \.self) { peer in Button(l("邀请 "+peer.displayName)) { connection.invite(peer) } }
                Divider()
                Text(l("在线房间（侧装可用）")).font(.headline)
                TextField(l("服务器地址，例如wss://relay.example.com"),text: $serverURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).focused($focused,equals: "server").accessibilityIdentifier("roomServer")
                TextField(l("房间号"),text: $roomCode)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder).focused($focused,equals: "code").accessibilityIdentifier("roomCode")
                Button(l("生成房间号")) { roomCode = String(UUID().uuidString.replacingOccurrences(of: "-",with: "").prefix(8)) }
                Button(l("进入在线房间")) { focused = nil; prepareRoom() }.disabled(connection.joiningRoom || connection.connected).accessibilityIdentifier("joinRoom")
                Text(l("双方使用相同服务器和房间号，不需要Apple开发账号。公网须使用wss；服务器程序随工程提供，需部署后填写地址。"))
                    .font(.caption).foregroundStyle(Palette.muted)
                if Bundle.main.object(forInfoDictionaryKey: "GameCenterEnabled") as? Bool == true {
                    Button(l("Game Center 在线匹配")) { prepare(online: true) }
                }
            }
            if let peer = connection.invitation {
                Text(l("\(peer.displayName) 邀请你连接"))
                HStack { Button(l("接受")) { connection.answerInvitation(true) }; Button(l("拒绝")) { connection.answerInvitation(false) } }
            }
            Button(l("断开连接")) { scene.stop(); model.audio.battleMusic(false); connection.reset(); playedID = nil; finished = false }
            Text(l("附近连接与在线房间均用于iPhone之间，不代表可以直接连接实体暴龙机。真实双机仍需验收。"))
                .font(.caption).foregroundStyle(Palette.muted)
        }.onChange(of: connection.outcome?.id) { _,_ in playResult() }
            .onDisappear { scene.stop(); connection.stop(); model.audio.battleMusic(false) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(l("完成")) { focused = nil }.accessibilityIdentifier("roomKeyboardDone") } }
    }
    private func prepareRoom() {
        guard let state = model.state,let database = model.database else { return }
        do {
            let url = try RoomEndpoint.url(server: serverURL,room: roomCode)
            connection.stop()
            connection.prepare(try ConnectionEngine.fighter(for: state,database: database),database: database)
            _ = url
            try connection.startRoom(server: serverURL,code: roomCode)
        } catch { connection.notice = error.localizedDescription }
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
            let evolved = model.state?.pet.speciesID != player.speciesID
            scene.onAudio = { model.emitAudio($0) }
            model.audio.battleMusic(true)
            scene.onFinished = {
                finished = true
                model.audio.battleMusic(false)
                if evolved { model.playEvolution(jogress: true) }
            }
            scene.playConnection(player: try database.species(player.speciesID),opponent: try database.species(remote.speciesID),result: result,mode: model.display,reduceMotion: reduced)
            playedID = result.id
        } catch { connection.notice = error.localizedDescription }
    }
}
