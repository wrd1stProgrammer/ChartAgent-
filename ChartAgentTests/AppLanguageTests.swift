import XCTest
@testable import ChartAgent

final class AppLanguageTests: XCTestCase {
    private let supportedCatalogLocales: Set<String> = [
        "en", "ko", "ja", "de", "fr", "es-MX", "pt-BR", "zh-Hant",
        "id", "th", "zh-Hans", "vi", "it", "tr", "es", "fr-CA",
    ]

    func testDefaultAgentProfileStoresCanonicalLocalizationKeys() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        defaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        let profile = AgentProfile.defaultProfile(for: PixelAgent.defaultTeam[0])

        XCTAssertEqual(profile.displayName, "트렌디")
        XCTAssertEqual(profile.tone, "간결하고 단호하게")
        XCTAssertEqual(profile.localizedDisplayName, "Trendy")
        XCTAssertEqual(profile.localizedTone, "Brief and decisive")
    }

    func testSelectingKoreanImmediatelyDrivesRuntimeLocalization() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                AppLanguage.select(rawValue: previous)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        AppLanguage.select(.korean)

        XCTAssertEqual(AppLanguage.current, .korean)
        XCTAssertEqual(AppLanguage.localized("에이전트 스튜디오"), "에이전트 스튜디오")
        XCTAssertEqual(AppLanguage.localized("무료 이용 중"), "무료 이용 중")
        XCTAssertEqual(AppLanguage.localized("실행 가격 지도"), "실행 가격 지도")
        XCTAssertEqual(AppLanguage.localized("뭐라고 불러드릴까요?"), "뭐라고 불러드릴까요?")
    }

    func testPersistedEnglishDefaultProfileMigratesBackToCanonicalKeys() throws {
        let suiteName = "AppLanguageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let englishDefault = try AgentProfile(
            roleID: "trend",
            displayName: "Trendy",
            tone: "Brief and decisive",
            concept: .swingStructure,
            appearanceID: "default_trendy"
        )
        defaults.set(try JSONEncoder().encode([
            englishDefault,
            AgentProfile.defaultProfile(for: PixelAgent.defaultTeam[1]),
            AgentProfile.defaultProfile(for: PixelAgent.defaultTeam[2]),
            AgentProfile.defaultProfile(for: PixelAgent.defaultTeam[3]),
            AgentProfile.defaultProfile(for: PixelAgent.defaultTeam[4]),
        ]), forKey: "agentProfiles.v1")

        let store = AgentProfileStore(defaults: defaults)
        XCTAssertEqual(store.profile(for: "trend")?.displayName, "트렌디")
        XCTAssertEqual(store.profile(for: "trend")?.tone, "간결하고 단호하게")
    }

    func testScreenshotKoreanCopyHasSemanticTranslations() throws {
        let catalog = try localizationCatalog()
        let expected: [String: String] = [
            "에이전트 스튜디오": "에이전트 스튜디오",
            "내 분석팀": "내 분석팀",
            "에이전트 편집": "에이전트 편집",
            "간결하고 단호하게": "간결하고 단호하게",
            "무료 이용 중": "무료 이용 중",
            "무료 분석 사용 완료": "무료 분석 사용 완료",
            "뭐라고 불러드릴까요?": "뭐라고 불러드릴까요?",
            "한 번의 답과\n검증된 결론은 달라요.": "한 번의 답과\n검증된 결론은 달라요.",
            "근거가 쌓일수록\n판단은 더 선명해져요.": "근거가 쌓일수록\n판단은 더 선명해져요.",
            "이 분석팀을 원해요": "이 분석팀을 원해요",
            "뉴스 반영 내역": "뉴스 반영 내역",
            "입력 품질": "입력 품질",
            "실행 가격 지도": "실행 가격 지도",
            "조건별 시나리오": "조건별 시나리오",
            "보이는 구조": "보이는 구조",
            "에이전트별 판단": "에이전트별 판단",
        ]

        for (key, value) in expected {
            XCTAssertEqual(catalogValue(for: key, locale: "ko", in: catalog), value, key)
        }
    }

    func testLanguagePickerContainsSystemAndSixteenStoreLocales() {
        XCTAssertEqual(AppLanguage.allCases.count, 17)
        XCTAssertEqual(
            Set(AppLanguage.allCases.dropFirst().map(\.responseLanguage)),
            Set([
                "en-US", "ko", "ja", "de", "fr-FR", "es-MX", "pt-BR", "zh-Hant",
                "id", "th", "zh-Hans", "vi", "it", "tr", "es-ES", "fr-CA",
            ])
        )
    }

    func testSystemLocaleUsesRegionAndScriptThenFallsBackToEnglishUS() {
        XCTAssertEqual(AppLanguage.supportedLocaleIdentifier("fr_CA"), "fr-CA")
        XCTAssertEqual(AppLanguage.supportedLocaleIdentifier("es_MX"), "es-MX")
        XCTAssertEqual(AppLanguage.supportedLocaleIdentifier("zh-Hant-HK"), "zh-Hant")
        XCTAssertEqual(AppLanguage.supportedLocaleIdentifier("zh_CN"), "zh-Hans")
        XCTAssertEqual(AppLanguage.supportedLocaleIdentifier("ar_SA"), "en-US")
    }

    func testDefaultAgentNamesAreCompleteInEverySupportedCatalogLocale() throws {
        let catalog = try localizationCatalog()

        let keys = [
            "트렌디", "패티", "모모", "가디", "데빌",
            "스윙 구조", "캔들·경계", "가격행동 강도", "레벨·무효화", "실패·페이크아웃",
            "최근 스윙 고점과 저점의 순서를 먼저 맞춰볼게요.",
            "이름 붙이기 전에 경계가 반복되는지부터 볼게요.",
            "몸통 확장과 꼬리 반응으로 힘의 변화를 비교할게요.",
            "판단이 틀렸다고 인정할 가격부터 정할게요.",
            "이 돌파가 실패했을 때 무엇이 먼저 보일지 찾을게요.",
        ]

        for key in keys {
            XCTAssertEqual(catalogLocales(for: key, in: catalog), supportedCatalogLocales, key)
        }
    }

    func testDynamicScreenCopyIsCompleteInEverySupportedCatalogLocale() throws {
        let catalog = try localizationCatalog()
        let keys = [
            "추세 추종", "역발상·반대 시나리오",
            "%@ 관점으로 차트 근거와 무효화 조건을 검증합니다.",
            "에이전트 이름", "말투", "ChartAgent PRO 활성", "구독 관리",
            "착석", "이동 중", "대기 중",
            "판단 근거 · %@",
            "ChartAgent · %@ (%@)\nAI 키와 시장 데이터 키는 서버에만 보관됩니다.",
            "내 정보 수정", "투자 경험", "관심 시장", "거래 스타일", "연결 완료",
            "%@ 관점의 근거를 정리하는 중…",
        ]

        for key in keys {
            XCTAssertEqual(catalogLocales(for: key, in: catalog), supportedCatalogLocales, key)
        }


        for concept in InvestmentConcept.allCases {
            XCTAssertEqual(
                catalogLocales(for: concept.localizationTitleKey, in: catalog),
                supportedCatalogLocales,
                concept.rawValue
            )
        }
    }

    func testStaticSheetAndOnboardingCopyIsCompleteInEverySupportedCatalogLocale() throws {
        let catalog = try localizationCatalog()
        let keys = [
            "%@ 문제를 먼저 점검하도록\n다섯 에이전트의 회의 순서를 맞췄어요.",
            "%@님의\n분석팀이 준비됐어요.",
            "결과는 어떻게 읽나요?",
            "결제는 어디서 관리하나요?",
            "뉴스 반영은 선택인가요?",
            "어떤 이미지를 올리나요?",
            "비밀 키",
            "필수 안내",
            "분석과 구독 제공에 필요한 정보가 처리됩니다.",
            "한 장의 차트를\n다섯 시선으로 끝까지.",
            "다섯 에이전트가 각자 읽고, 서로 반박한 뒤\n실행 가능한 조건만 한 리포트로 남깁니다.",
        ]

        for key in keys {
            XCTAssertEqual(catalogLocales(for: key, in: catalog), supportedCatalogLocales, key)
        }
    }

    private func localizationCatalog() throws -> [String: Any] {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("ChartAgent/Localizable.xcstrings"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(root["strings"] as? [String: Any])
    }

    private func catalogLocales(for key: String, in catalog: [String: Any]) -> Set<String> {
        guard let entry = catalog[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else { return [] }
        return Set(localizations.keys)
    }

    private func catalogValue(for key: String, locale: String, in catalog: [String: Any]) -> String? {
        guard let entry = catalog[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[locale] as? [String: Any],
              let unit = localization["stringUnit"] as? [String: Any] else { return nil }
        return unit["value"] as? String
    }
}
