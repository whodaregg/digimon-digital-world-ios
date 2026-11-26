import Foundation
import CZlib

/// Reads bounded, flat resource packs without extracting a caller-controlled path.
public enum AudioZIP {
    public static let maxArchiveBytes = 128 * 1024 * 1024
    public static let maxFileBytes = 32 * 1024 * 1024
    public enum Invalid: LocalizedError {
        case archive, unsupported, limit, entry
        public var errorDescription: String? {
            switch self {
            case .archive: return "ZIP 目录或校验值无效。"
            case .unsupported: return "仅支持单卷、未加密的标准 ZIP（Stored 或 Deflate）。"
            case .limit: return "音频包超出文件数或容量限制。"
            case .entry: return "ZIP 内必须使用不重复的文件名，且不能包含子目录或链接。"
            }
        }
    }

    public static func unpack(_ input: Data) throws -> [String: Data] {
        let data = Data(input)
        guard data.count <= maxArchiveBytes else { throw Invalid.limit }
        guard data.count >= 22 else { throw Invalid.archive }
        func u16(_ offset: Int) -> Int {
            Int(data[offset]) | Int(data[offset + 1]) << 8
        }
        func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }
        let last = data.count - 22
        guard let end = stride(from: last, through: max(0, last - 65535), by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == data.count
        }) else { throw Invalid.archive }
        let count = u16(end + 10)
        guard u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == count else { throw Invalid.unsupported }
        guard (1...256).contains(count) else { throw Invalid.limit }
        let centralStart = u32(end + 16)
        guard centralStart <= end, u32(end + 12) == end - centralStart else { throw Invalid.archive }
        var cursor = centralStart
        var total = 0
        var files: [String: Data] = [:]
        var seen = Set<String>()
        for _ in 0..<count {
            guard cursor + 46 <= end, u32(cursor) == 0x02014b50 else { throw Invalid.archive }
            let flags = u16(cursor + 8)
            let method = u16(cursor + 10)
            guard flags & ~0x080e == 0, method == 0 || method == 8, u16(cursor + 34) == 0 else {
                throw Invalid.unsupported
            }
            let compressedSize = u32(cursor + 20)
            let size = u32(cursor + 24)
            guard (1...maxFileBytes).contains(size), total + size <= maxArchiveBytes else { throw Invalid.limit }
            let nameLength = u16(cursor + 28)
            let nameEnd = cursor + 46 + nameLength
            let next = nameEnd + u16(cursor + 30) + u16(cursor + 32)
            guard next <= end else { throw Invalid.archive }
            let nameBytes = data[(cursor + 46)..<nameEnd]
            let unixMode = u32(cursor + 38) >> 16
            guard let name = String(bytes: nameBytes, encoding: .utf8), !name.isEmpty, name.count <= 255,
                  !name.hasPrefix("."), !name.contains("/"), !name.contains("\\"),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  unixMode & 0xf000 != 0xa000, seen.insert(name.lowercased()).inserted else { throw Invalid.entry }
            let local = u32(cursor + 42)
            guard local + 30 <= centralStart, u32(local) == 0x04034b50, u16(local + 6) == flags,
                  u16(local + 8) == method, u16(local + 26) == nameLength else { throw Invalid.archive }
            let localNameEnd = local + 30 + nameLength
            let payload = localNameEnd + u16(local + 28)
            guard payload <= centralStart, compressedSize <= centralStart - payload,
                  data[(local + 30)..<localNameEnd].elementsEqual(nameBytes) else { throw Invalid.archive }
            let bytes = Data(data[payload..<(payload + compressedSize)])
            let decoded: Data
            if method == 0 {
                guard bytes.count == size else { throw Invalid.archive }
                decoded = bytes
            } else {
                decoded = try inflateRaw(bytes, size: size)
            }
            let checksum = decoded.withUnsafeBytes { buffer in
                crc32(0, buffer.bindMemory(to: Bytef.self).baseAddress, uInt(size))
            }
            guard checksum == UInt32(u32(cursor + 16)) else { throw Invalid.archive }
            total += size
            files[name] = decoded
            cursor = next
        }
        guard cursor == end else { throw Invalid.archive }
        return files
    }

    private static func inflateRaw(_ compressed: Data, size: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw Invalid.archive
        }
        defer { inflateEnd(&stream) }
        var output = Data(count: size)
        let status = compressed.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(source.count)
                stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(destination.count)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END, stream.total_out == size, stream.total_in == compressed.count else { throw Invalid.archive }
        return output
    }
}
