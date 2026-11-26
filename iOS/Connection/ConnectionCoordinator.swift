import SwiftUI
@preconcurrency import MultipeerConnectivity
@preconcurrency import GameKit
import DigitalWorldCore

@MainActor
final class ConnectionCoordinator: NSObject,ObservableObject {
    @Published var peers: [MCPeerID] = []
    @Published var invitation: MCPeerID?
    @Published var remote: ConnectionFighter?
    @Published var outcome: ConnectionBattleResult?
    @Published var notice = "尚未开始搜索"
    @Published var connected = false
    @Published var ready = false
    @Published private(set) var joiningRoom = false
    private(set) var local: ConnectionFighter?
    private var database: ContentDatabase?
    private let peer = MCPeerID(displayName: "Player-"+String(UUID().uuidString.prefix(6)))
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var acceptInvitation: ((Bool,MCSession?) -> Void)?
    private var remoteReady = false
    private var match: GKMatch?
    private var packetSent = false
    private var invitedPeer: MCPeerID?
    private var generation = UUID()
    private weak var onlinePicker: GKMatchmakerViewController?
    private var socket: URLSessionWebSocketTask?
    private var roomTask: Task<Void,Never>?
    private struct Packet: Codable { var kind: String; var fighter: ConnectionFighter? }
    func prepare(_ fighter: ConnectionFighter,database: ContentDatabase) { local = fighter; self.database = database; remote = nil; outcome = nil; ready = false; remoteReady = false; packetSent = false }
    func searchNearby() {
        stop(); notice = "正在搜索附近玩家；双方需打开此页面并允许本地网络"
        let session = MCSession(peer: peer,securityIdentity: nil,encryptionPreference: .required); session.delegate = self; self.session = session
        let browser = MCNearbyServiceBrowser(peer: peer,serviceType: "world-pets"); browser.delegate = self; self.browser = browser
        let advertiser = MCNearbyServiceAdvertiser(peer: peer,discoveryInfo: ["protocol":"2"],serviceType: "world-pets")
        advertiser.delegate = self; self.advertiser = advertiser; advertiser.startAdvertisingPeer(); browser.startBrowsingForPeers()
    }
    func invite(_ target: MCPeerID) { guard let session,!connected,invitedPeer == nil,invitation == nil else { return }; invitedPeer = target; browser?.invitePeer(target,to: session,withContext: nil,timeout: 30); notice = "已邀请 \(target.displayName)，等待对方接受" }
    func answerInvitation(_ accepted: Bool) { acceptInvitation?(accepted,accepted ? session : nil); acceptInvitation = nil; invitation = nil }
    func confirmBattle() {
        guard connected,!ready,remote != nil,local != nil else { return }
        do { try send(Packet(kind: "ready",fighter: local)); ready = true; resolveIfReady() }
        catch { notice = error.localizedDescription }
    }
    func reset() {
        stop(); local = nil; remote = nil; outcome = nil; ready = false; remoteReady = false; packetSent = false; notice = "尚未开始搜索"
    }
    func stop() {
        generation = UUID(); onlinePicker?.dismiss(animated: true); onlinePicker = nil
        roomTask?.cancel(); roomTask = nil; socket?.cancel(with: .goingAway,reason: nil); socket = nil; joiningRoom = false
        browser?.stopBrowsingForPeers(); advertiser?.stopAdvertisingPeer(); session?.disconnect(); match?.disconnect()
        browser = nil; advertiser = nil; session = nil; match = nil; peers = []; connected = false; invitedPeer = nil
        answerInvitation(false)
    }
    private func send(_ packet: Packet) throws {
        let data = try JSONEncoder().encode(packet)
        if let socket {
            let expected = generation
            socket.send(.data(data)) { [weak self] error in
                Task { @MainActor in
                    guard let self,self.generation == expected,let error else { return }
                    self.ready = false; self.notice = error.localizedDescription
                }
            }
        }
        else if let match { try match.sendData(toAllPlayers: data,with: .reliable) }
        else if let session,!session.connectedPeers.isEmpty { try session.send(data,toPeers: session.connectedPeers,with: .reliable) }
        else { throw GameError.unavailable("连接已断开") }
    }
    private func becameConnected() {
        browser?.stopBrowsingForPeers(); advertiser?.stopAdvertisingPeer()
        connected = true; notice = "已连接，正在交换机型与伙伴信息"
        do { try send(Packet(kind: "hello",fighter: local)) } catch { notice = error.localizedDescription }
    }
    private func receive(_ data: Data) {
        guard data.count <= 16_384,let database else { notice = "通信数据过大或内容库不可用"; return }
        do {
            let packet = try JSONDecoder().decode(Packet.self,from: data)
            if packet.kind == "hello",let fighter = packet.fighter {
                try ConnectionEngine.validate(fighter,database: database)
                guard local?.sandbox == fighter.sandbox,local?.petID != fighter.petID else { throw GameError.cannotAct("双方必须是不同伙伴，且Sandbox与正式养成不能混战") }
                if ready {
                    guard remote == fighter else { throw GameError.cannotAct("准备后伙伴信息发生变化，请重新连接") }
                    resolveIfReady(); return
                }
                remote = fighter; notice = "双方信息已收到，双方确认后开始对战"
            } else if packet.kind == "ready",let fighter = packet.fighter {
                try ConnectionEngine.validate(fighter,database: database)
                guard let remote,remote == fighter else { throw GameError.cannotAct("确认消息与伙伴信息不一致，请重新连接") }
                remoteReady = true; resolveIfReady()
            }
            else { throw GameError.invalidData("未知通信消息") }
        } catch { notice = error.localizedDescription }
    }
    private func resolveIfReady() {
        guard ready,remoteReady,!packetSent,let local,let remote,let database else { return }
        do { outcome = try ConnectionEngine.resolve(player: local,opponent: remote,database: database); packetSent = true; notice = "战果已共同确定" }
        catch { notice = error.localizedDescription }
    }
    func startRoom(server: String,code: String) throws {
        let url = try RoomEndpoint.url(server: server,room: code)
        var request = URLRequest(url: url); request.timeoutInterval = 20
        let task = URLSession.shared.webSocketTask(with: request)
        socket = task; joiningRoom = true; notice = "正在连接房间，等待另一位玩家"
        let expected = generation
        task.resume()
        roomTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard let self,self.generation == expected,self.socket === task else { return }
                    let data: Data
                    switch message { case .data(let bytes): data = bytes; case .string(let text): data = Data(text.utf8); @unknown default: continue }
                    guard data.count <= 16_384 else { throw GameError.invalidData("在线消息超过容量上限") }
                    if let control = try JSONSerialization.jsonObject(with: data) as? [String:Any],let type = control["type"] as? String {
                        switch type {
                        case "waiting": self.notice = "房间已创建，等待另一位玩家使用相同房间号进入"
                        case "ready": self.joiningRoom = false; self.becameConnected()
                        case "peer-left": self.stop(); self.notice = "对方已离开房间，请重新进入后继续"; return
                        default: self.stop(); self.notice = "房间服务器拒绝连接"; return
                        }
                    } else { self.receive(data) }
                } catch {
                    guard let self,self.generation == expected else { return }
                    self.stop(); self.notice = "在线连接失败：\(error.localizedDescription)"; return
                }
            }
        }
    }
    func startOnline(from presenter: UIViewController) {
        guard Bundle.main.object(forInfoDictionaryKey: "GameCenterEnabled") as? Bool == true else { notice = "此构建未配置Game Center；需开发团队启用能力并注册Bundle ID"; return }
        let expectedGeneration = generation
        GKLocalPlayer.local.authenticateHandler = { [weak self,weak presenter] controller,error in
            Task { @MainActor in
                guard let self,let presenter,self.generation == expectedGeneration else { return }
                if let controller { presenter.present(controller,animated: true); return }
                if let error { self.notice = error.localizedDescription; return }
                guard GKLocalPlayer.local.isAuthenticated else { self.notice = "尚未登录Game Center"; return }
                let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 2
                guard let picker = GKMatchmakerViewController(matchRequest: request) else { self.notice = "无法打开在线匹配"; return }
                picker.matchmakerDelegate = self; self.onlinePicker = picker; presenter.present(picker,animated: true)
            }
        }
    }
}

extension ConnectionCoordinator: MCNearbyServiceBrowserDelegate,MCNearbyServiceAdvertiserDelegate,MCSessionDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,foundPeer peerID: MCPeerID,withDiscoveryInfo info: [String:String]?) {
        Task { @MainActor in if self.browser === browser,info?["protocol"] == "2",!self.peers.contains(peerID) { self.peers.append(peerID) } }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,lostPeer peerID: MCPeerID) { Task { @MainActor in if self.browser === browser { self.peers.removeAll { $0 == peerID } } } }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,didNotStartBrowsingForPeers error: Error) { Task { @MainActor in self.notice = error.localizedDescription } }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,didReceiveInvitationFromPeer peerID: MCPeerID,withContext context: Data?,invitationHandler: @escaping (Bool,MCSession?) -> Void) {
        Task { @MainActor in
            guard self.advertiser === advertiser,!self.connected,self.invitation == nil,self.invitedPeer == nil else { invitationHandler(false,nil); return }
            self.invitation = peerID; self.acceptInvitation = invitationHandler
        }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,didNotStartAdvertisingPeer error: Error) { Task { @MainActor in self.notice = error.localizedDescription } }
    nonisolated func session(_ session: MCSession,peer peerID: MCPeerID,didChange state: MCSessionState) {
        Task { @MainActor in
            guard self.session === session else { return }
            if state == .connected { self.becameConnected() }
            else if state == .notConnected { self.connected = false; self.invitedPeer = nil; self.notice = "连接已断开；已保存战果不会重复发放" }
        }
    }
    nonisolated func session(_ session: MCSession,didReceive data: Data,fromPeer peerID: MCPeerID) { Task { @MainActor in if self.session === session,session.connectedPeers.count == 1,session.connectedPeers.first == peerID { self.receive(data) } } }
    nonisolated func session(_ session: MCSession,didReceive stream: InputStream,withName streamName: String,fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession,didStartReceivingResourceWithName name: String,fromPeer peerID: MCPeerID,with progress: Progress) {}
    nonisolated func session(_ session: MCSession,didFinishReceivingResourceWithName name: String,fromPeer peerID: MCPeerID,at localURL: URL?,withError error: Error?) {}
}
extension ConnectionCoordinator: GKMatchmakerViewControllerDelegate,GKMatchDelegate {
    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) { Task { @MainActor in if self.onlinePicker === viewController { self.onlinePicker = nil; viewController.dismiss(animated: true) } } }
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController,didFailWithError error: Error) {
        Task { @MainActor in guard self.onlinePicker === viewController else { return }; self.onlinePicker = nil; self.notice = error.localizedDescription; viewController.dismiss(animated: true) }
    }
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController,didFind match: GKMatch) {
        Task { @MainActor in guard self.onlinePicker === viewController else { match.disconnect(); return }; self.onlinePicker = nil; self.match = match; match.delegate = self; viewController.dismiss(animated: true); if match.expectedPlayerCount == 0 { self.becameConnected() } }
    }
    nonisolated func match(_ match: GKMatch,didReceive data: Data,fromRemotePlayer player: GKPlayer) { Task { @MainActor in if self.match === match { self.receive(data) } } }
    nonisolated func match(_ match: GKMatch,player: GKPlayer,didChange state: GKPlayerConnectionState) {
        Task { @MainActor in guard self.match === match else { return }; if state == .connected && match.expectedPlayerCount == 0 { self.becameConnected() }; if state == .disconnected { self.connected = false; self.notice = "在线对方已离开" } }
    }
    nonisolated func match(_ match: GKMatch,didFailWithError error: Error?) { Task { @MainActor in if self.match === match { self.notice = error?.localizedDescription ?? "在线连接失败" } } }
}
