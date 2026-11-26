import Foundation

public enum RoomEndpoint {
    public static func url(server: String,room: String) throws -> URL {
        let code = room.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (6...32).contains(code.count),code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { throw GameError.cannotAct("房间号需为6至32位字母、数字或短横线") }
        guard var parts = URLComponents(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              let rawHost = parts.host,!rawHost.isEmpty,parts.user == nil,parts.password == nil,parts.query == nil,parts.fragment == nil else { throw GameError.cannotAct("请输入有效的在线服务器地址") }
        let host = rawHost.lowercased()
        parts.scheme = parts.scheme?.lowercased()
        if parts.scheme == "https" { parts.scheme = "wss" }
        if parts.scheme == "http" { parts.scheme = "ws" }
        let labels = host.split(separator: ".")
        let numbers = labels.compactMap { Int($0) }
        let privateIP = labels.count == 4 && numbers.count == 4 && numbers.allSatisfy { (0...255).contains($0) } && (numbers[0] == 10 || (numbers[0] == 192 && numbers[1] == 168) || (numbers[0] == 172 && (16...31).contains(numbers[1])))
        let local = ["localhost","127.0.0.1","::1"].contains(host) || privateIP || host.hasSuffix(".local")
        guard parts.scheme == "wss" || (parts.scheme == "ws" && local) else { throw GameError.cannotAct("公网服务器请使用wss加密地址；ws仅用于本机或局域网") }
        parts.path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        parts.path = "/" + (parts.path.isEmpty ? "" : parts.path+"/") + "room/"+code
        guard let url = parts.url else { throw GameError.cannotAct("在线服务器地址无效") }
        return url
    }
}
