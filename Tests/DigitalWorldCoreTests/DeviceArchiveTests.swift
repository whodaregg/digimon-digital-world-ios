import XCTest
@testable import DigitalWorldCore

final class DeviceArchiveTests: XCTestCase {
    func testArchiveRestoresLinkedDevicesWithoutOverwritingExistingProgress() throws {
        let db = try ContentDatabase.bundled(),now = Date(timeIntervalSince1970: 1_800_446_400)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = DeviceLibraryStore(directory: root.appendingPathComponent("source"),database: db)
        var index = DeviceLibraryIndex()
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        game.sessionStyle = .classic
        let formal = try source.add(game,to: &index,at: now)
        game.sessionStyle = .sandbox; game.developerModifiedAt = now
        let sandbox = try source.add(game,to: &index,at: now,sourceSlotID: formal.id)
        let archive = try DeviceArchive.decode(DeviceArchive.capture(index: index,library: source,at: now).encode(),library: source)
        let destination = DeviceLibraryStore(directory: root.appendingPathComponent("destination"),database: db)
        var target = DeviceLibraryIndex()
        var existing = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        existing.settings.display = .lcd
        let preserved = try destination.add(existing,to: &target,at: now)
        let selected = try archive.restore(library: destination,index: &target,at: now)
        XCTAssertEqual(target.activeID,preserved.id)
        XCTAssertEqual(try destination.store(for: preserved).load()?.state,existing)
        XCTAssertEqual(target.slots.count,3)
        let importedSandbox = try XCTUnwrap(target.slots.first { $0.id == selected })
        XCTAssertNotEqual(importedSandbox.id,sandbox.id)
        XCTAssertEqual(target.formalSource(for: importedSandbox.id)?.style,.classic)
        XCTAssertEqual(try destination.store(for: importedSandbox).load()?.state.playStyle,.sandbox)
        XCTAssertEqual(try destination.loadIndex(),target)
    }
    func testCorruptAndInvalidArchivesCannotPublishAnyDevice() throws {
        let db = try ContentDatabase.bundled(),now = Date(timeIntervalSince1970: 1_800_446_400)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = DeviceLibraryStore(directory: dir,database: db); var index = DeviceLibraryIndex()
        let game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        _ = try library.add(game,to: &index,at: now)
        var archive = try DeviceArchive.capture(index: index,library: library,at: now)
        let before = index
        archive.entries.append(archive.entries[0])
        XCTAssertThrowsError(try archive.restore(library: library,index: &index,at: now))
        XCTAssertEqual(index,before); XCTAssertEqual(try library.loadIndex(),before)
        XCTAssertThrowsError(try DeviceArchive.decode(Data("corrupt".utf8),library: library))
    }
}

final class LocalizationTests: XCTestCase {
    func testMessagesTranslateCapturedValuesAndOriginalSpeciesNames() {
        XCTAssertGreaterThan(GameLocalization.coverage,700)
        let source = "已指定 电光暴龙兽"
        XCTAssertTrue(GameLocalization.text(source,language: .english).contains("BlitzGreymon"))
        XCTAssertTrue(GameLocalization.text(source,language: .traditional).contains("電光暴龍獸"))
        let issued = GameLocalization.text("已发放 8 × evolution-chip",language: .english)
        XCTAssertTrue(issued.contains("8")); XCTAssertTrue(issued.contains("evolution-chip"))
        XCTAssertFalse(issued.contains("已发放"))
        XCTAssertEqual(GameLocalization.text(source,language: .simplified),source)
    }
}
