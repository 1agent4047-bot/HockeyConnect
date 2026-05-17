import XCTest
@testable import HockeyConnect

final class HockeyConnectTests: XCTestCase {

    func testSkillLabelMapping() {
        let profile = PlayerProfile(skillLevel: 1, age: 25, availability: [])
        XCTAssertEqual(profile.skillLabel, "Beginner")

        let elite = PlayerProfile(skillLevel: 5, age: 30, availability: [])
        XCTAssertEqual(elite.skillLabel, "Elite")
    }

    func testGameIsFullWhenNoSpots() {
        let game = Game(
            groupId: "g1", groupName: "Hawks", rinkName: "AZ Ice",
            date: Date(), skillLevelRequired: 3, spotsTotal: 2, spotsAvailable: 0,
            applicantIds: [], selectedPlayerIds: [], status: .open
        )
        XCTAssertTrue(game.isFull)
    }

    func testGameNotFullWithSpots() {
        let game = Game(
            groupId: "g1", groupName: "Hawks", rinkName: "AZ Ice",
            date: Date(), skillLevelRequired: 3, spotsTotal: 5, spotsAvailable: 3,
            applicantIds: [], selectedPlayerIds: [], status: .open
        )
        XCTAssertFalse(game.isFull)
    }
}
