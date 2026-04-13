import XCTest
@testable import XEye

final class GameLogicTests: XCTestCase {
    func testXPFormulaLevel() {
        XCTAssertEqual(XPFormula.level(for: 0), 1)
        XCTAssertEqual(XPFormula.level(for: XPFormula.xpForLevel(2)), 2)
    }

    func testRarityRollBoundaries() {
        XCTAssertEqual(RarityRoller.roll(random: 0.0), .ssr)
        XCTAssertEqual(RarityRoller.roll(random: 0.10), .sr)
        XCTAssertEqual(RarityRoller.roll(random: 0.30), .r)
        XCTAssertEqual(RarityRoller.roll(random: 0.90), .n)
    }

    func testComboMultiplier() {
        let combo = ComboManager()
        _ = combo.recordExamine(now: Date())
        _ = combo.recordExamine(now: Date().addingTimeInterval(10))
        _ = combo.recordExamine(now: Date().addingTimeInterval(20))
        XCTAssertEqual(combo.comboMultiplier, 1.5)
    }
}
