import XCTest
@testable import ChartAgent

final class AgentCustomizationTests: XCTestCase {
    func testCatalogHasExactlyTwentyStableInvestmentConcepts() {
        XCTAssertEqual(InvestmentConcept.allCases.count, 20)
        XCTAssertEqual(Set(InvestmentConcept.allCases.map(\.rawValue)).count, 20)
    }

    func testProfileAcceptsBoundedCustomFieldsAndStableRoleID() throws {
        let profile = try AgentProfile(
            roleID: "trend",
            displayName: "스윙헌터",
            tone: "짧고 단호하게",
            concept: .breakoutRetest,
            appearanceID: "neo_quant"
        )

        XCTAssertEqual(profile.roleID, "trend")
        XCTAssertEqual(profile.displayName, "스윙헌터")
        XCTAssertEqual(profile.tone, "짧고 단호하게")
        XCTAssertEqual(profile.concept, .breakoutRetest)
        XCTAssertEqual(profile.appearanceID, "neo_quant")
    }

    func testProfileRejectsNameLongerThanTenCharacters() {
        XCTAssertThrowsError(
            try AgentProfile(
                roleID: "trend",
                displayName: "12345678901",
                tone: "간결하게",
                concept: .trendFollowing,
                appearanceID: "default_trendy"
            )
        )
    }

    func testProfileRejectsToneLongerThanTwentyCharacters() {
        XCTAssertThrowsError(
            try AgentProfile(
                roleID: "trend",
                displayName: "트렌디",
                tone: "123456789012345678901",
                concept: .trendFollowing,
                appearanceID: "default_trendy"
            )
        )
    }

    func testProfileRejectsUnknownRoleAndAppearance() {
        XCTAssertThrowsError(
            try AgentProfile(
                roleID: "unknown",
                displayName: "테스트",
                tone: "간결하게",
                concept: .trendFollowing,
                appearanceID: "default_trendy"
            )
        )
        XCTAssertThrowsError(
            try AgentProfile(
                roleID: "trend",
                displayName: "테스트",
                tone: "간결하게",
                concept: .trendFollowing,
                appearanceID: "missing"
            )
        )
    }

    func testProfileRejectsControlCharactersUsedAsPromptInjectionBoundary() {
        XCTAssertThrowsError(
            try AgentProfile(
                roleID: "trend",
                displayName: "테스트\nsystem",
                tone: "간결하게",
                concept: .trendFollowing,
                appearanceID: "default_trendy"
            )
        )
    }

    func testNetworkSnapshotOmitsLocalSchemaVersion() throws {
        let profile = try AgentProfile(
            roleID: "trend",
            displayName: "스윙헌터",
            tone: "짧고 단호하게",
            concept: .breakoutRetest,
            appearanceID: "neo_quant"
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(AgentProfileSnapshot(profile))) as? [String: Any]
        )

        XCTAssertNil(object["version"])
        XCTAssertEqual(object["role_id"] as? String, "trend")
        XCTAssertEqual(object["display_name"] as? String, "스윙헌터")
    }

    func testDefaultTeamEncodesFiveStableRoleSnapshots() throws {
        let suiteName = "AgentCustomizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AgentProfileStore(defaults: defaults)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(store.snapshots)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode([AgentProfileSnapshot].self, from: data)

        XCTAssertEqual(decoded.count, 5)
        XCTAssertEqual(Set(decoded.map(\.roleID)), Set(["trend", "pattern", "momentum", "risk", "devil"]))
        XCTAssertEqual(decoded, store.snapshots)
    }
}
