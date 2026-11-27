import Foundation

public enum BundledAudioLibrary {
    public static func manifestData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "community-audio", withExtension: "json") else {
            throw GameError.invalidData("缺少社区录音清单")
        }
        return try Data(contentsOf: url)
    }

    public static func fileURL(_ filename: String) -> URL? {
        guard filename.hasPrefix("community-"), filename.hasSuffix(".wav"),
              filename == URL(fileURLWithPath: filename).lastPathComponent else { return nil }
        return Bundle.module.url(forResource: String(filename.dropLast(4)), withExtension: "wav")
    }
}
