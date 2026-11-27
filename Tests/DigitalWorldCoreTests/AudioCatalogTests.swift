import XCTest
@testable import DigitalWorldCore

final class AudioCatalogTests: XCTestCase {
    func testCommunityRecordingsOnlyProvideLowerPriorityHybridFallback() {
        let map = AudioMapping(event: .keyPress, category: .communityRecording, source: "community archive",
                               authorization: "user requested", channel: .sfx)
        let context = AudioContext(deviceID: "dmc-ver1", series: .adventure)
        XCTAssertTrue(map.isValid)
        XCTAssertNil(map.score(for: .keyPress, mode: .classic, context: context))
        XCTAssertNil(map.score(for: .keyPress, mode: .anime, context: context))
        XCTAssertEqual(map.score(for: .keyPress, mode: .hybrid, context: context), -1000)
        var exact = AudioMapping(event: .keyPress, category: .deviceSFX, source: "owned", authorization: "licensed", channel: .sfx)
        exact.deviceID = context.deviceID
        XCTAssertGreaterThan(exact.score(for: .keyPress, mode: .hybrid, context: context) ?? -2000, -1000)
        var mislabeled = map
        mislabeled.deviceID = context.deviceID
        XCTAssertFalse(mislabeled.isValid)
    }

    func testBundledCommunityManifestContainsRealWaveFilesAndValidMappings() throws {
        struct Asset: Decodable { var mapping: AudioMapping; var originalFilename: String }
        struct Pack: Decodable { var version: Int; var assets: [Asset] }
        let pack = try JSONDecoder().decode(Pack.self, from: BundledAudioLibrary.manifestData())
        XCTAssertEqual(pack.version, 1)
        XCTAssertEqual(pack.assets.count, 23)
        XCTAssertEqual(Set(pack.assets.map(\.originalFilename)).count, 19)
        for asset in pack.assets {
            XCTAssertTrue(asset.mapping.isValid)
            XCTAssertEqual(asset.mapping.category, .communityRecording)
            let url = try XCTUnwrap(BundledAudioLibrary.fileURL(asset.originalFilename))
            let data = try Data(contentsOf: url)
            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: data[8..<12], encoding: .ascii), "WAVE")
        }
        XCTAssertNil(BundledAudioLibrary.fileURL("../community-click.wav"))
    }

    func testModeAndDeviceSpecificityDoNotTreatAnotherDeviceCueAsOriginal() {
        var map = AudioMapping(event: .keyPress, category: .deviceSFX, source: "owned", authorization: "licensed", channel: .sfx)
        map.deviceID = "one"
        let context = AudioContext(deviceID: "one", series: .tamers)
        XCTAssertNotNil(map.score(for: .keyPress, mode: .classic, context: context))
        XCTAssertNotNil(map.score(for: .keyPress, mode: .hybrid, context: context))
        XCTAssertNil(map.score(for: .keyPress, mode: .anime, context: context))
        XCTAssertNil(map.score(for: .keyPress, mode: .hybrid, context: .init(deviceID: "two")))
        map.deviceID = nil
        XCTAssertFalse(map.isValid)
    }

    func testEvolutionMusicMatchesSeriesTypeAndStageOnly() {
        var music = AudioMapping(event: .evolutionMusic, category: .animeBGM, source: "owned", authorization: "licensed", channel: .evolutionMusic)
        music.series = .adventure02
        music.evolutionType = .armorEvolution
        music.stage = "armor"
        var context = AudioContext(deviceID: "one", series: .adventure02, evolutionType: .armorEvolution, stage: "armor")
        XCTAssertNil(music.score(for: .evolutionMusic, mode: .classic, context: context))
        XCTAssertNotNil(music.score(for: .evolutionMusic, mode: .hybrid, context: context))
        context.evolutionType = .jogress
        XCTAssertNil(music.score(for: .evolutionMusic, mode: .anime, context: context))
        context.evolutionType = .armorEvolution
        context.stage = "mega"
        XCTAssertNil(music.score(for: .evolutionMusic, mode: .anime, context: context))
    }

    func testZIPStoredDeflateAndCorruptOrUnsafeEntry() throws {
        let stored = try XCTUnwrap(Data(base64Encoded: "UEsDBBQAAAAAAAAAIVBSvdiUGgAAABoAAAAIAAAAY2xpcC53YXZldmVudCBhdWRpbyBpbXBvcnQgZml4dHVyZVBLAQIUAxQAAAAAAAAAIVBSvdiUGgAAABoAAAAIAAAAAAAAAAAAAACAAQAAAABjbGlwLndhdlBLBQYAAAAAAQABADYAAABAAAAAAAA="))
        let deflate = try XCTUnwrap(Data(base64Encoded: "UEsDBBQAAAAIAAAAIVBSvdiUHAAAABoAAAAIAAAAY2xpcC53YXZLLUvNK1FILE3JzFfIzC3ILypRSMusKCktSgUAUEsBAhQDFAAAAAgAAAAhUFK92JQcAAAAGgAAAAgAAAAAAAAAAAAAAIABAAAAAGNsaXAud2F2UEsFBgAAAAABAAEANgAAAEIAAAAAAA=="))
        let traversal = try XCTUnwrap(Data(base64Encoded: "UEsDBBQAAAAAAAAAIVBSvdiUGgAAABoAAAALAAAALi4vY2xpcC53YXZldmVudCBhdWRpbyBpbXBvcnQgZml4dHVyZVBLAQIUAxQAAAAAAAAAIVBSvdiUGgAAABoAAAALAAAAAAAAAAAAAACAAQAAAAAuLi9jbGlwLndhdlBLBQYAAAAAAQABADkAAABDAAAAAAA="))
        let expected = ["clip.wav": Data("event audio import fixture".utf8)]
        XCTAssertEqual(try AudioZIP.unpack(stored), expected)
        XCTAssertEqual(try AudioZIP.unpack(deflate), expected)
        XCTAssertThrowsError(try AudioZIP.unpack(traversal))
        XCTAssertThrowsError(try AudioZIP.unpack(Data(deflate.dropLast())))
        var corrupted = stored
        corrupted[38] ^= 1
        XCTAssertThrowsError(try AudioZIP.unpack(corrupted))
    }

    func testMeasuredStepsAndTiltDoNotRepeatForTheSameGesture() {
        var sensor = SensorTrainingInput()
        XCTAssertEqual(sensor.walking(steps: 9, key: "A"), [])
        XCTAssertEqual(sensor.walking(steps: 21, key: "B"), ["B","B"])
        XCTAssertEqual(sensor.walking(steps: 21, key: "A"), [])
        XCTAssertEqual(sensor.walking(steps: 18, key: "A"), [])
        XCTAssertEqual(sensor.walking(steps: 999, key: "A"), ["A","A","A"])
        XCTAssertEqual(sensor.tilt(gravityX: 0.6), "A")
        XCTAssertNil(sensor.tilt(gravityX: -0.7))
        XCTAssertNil(sensor.tilt(gravityX: 0.1))
        XCTAssertEqual(sensor.tilt(gravityX: -0.7), "B")
    }
}
