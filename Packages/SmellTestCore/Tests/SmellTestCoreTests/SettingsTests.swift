import Testing
@testable import SmellTestCore

struct SettingsTests {
    @Test func missingValuesUseDefaults() {
        #expect(Settings.from(cloudModel: nil, secondOpinionEnabled: nil, minWarningSigns: nil, currentPatterns: nil) == .defaults)
    }

    @Test func validValuesApply() {
        let s = Settings.from(cloudModel: "gemini-3.8-flash", secondOpinionEnabled: "false",
                              minWarningSigns: "3", currentPatterns: "Fake toll texts\n\nFake parcel fees")
        #expect(s.cloudModel == "gemini-3.8-flash")
        #expect(!s.secondOpinionEnabled)
        #expect(s.minWarningSigns == 3)
        #expect(s.currentPatterns == ["Fake toll texts", "Fake parcel fees"])
    }

    @Test func badValuesFallBack() {
        let s = Settings.from(cloudModel: "https://evil.example/model", secondOpinionEnabled: "maybe",
                              minWarningSigns: "0", currentPatterns: nil)
        #expect(s.cloudModel == Settings.defaults.cloudModel)
        #expect(s.secondOpinionEnabled)
        #expect(s.minWarningSigns == 2)
        #expect(Settings.from(cloudModel: nil, secondOpinionEnabled: nil, minWarningSigns: "99", currentPatterns: nil).minWarningSigns == 2)
    }

    @Test func patternsAreCapped() {
        let many = (1...9).map { "Pattern \($0)" }.joined(separator: "\n") + "\n" + String(repeating: "x", count: 500)
        let s = Settings.from(cloudModel: nil, secondOpinionEnabled: nil, minWarningSigns: nil, currentPatterns: many)
        #expect(s.currentPatterns.count == 5)
        #expect(s.currentPatterns.allSatisfy { $0.count <= 120 })
    }

    @Test func thresholdChangesEscalation() {
        let twoSigns = "Final notice: pay the $6.99 fee."  // urgency + payment pressure
        let quiet = CheckResult(verdict: .noRedFlags, scamType: .none, summary: "s", reasons: [], nextSteps: ["a", "b", "c"])
        #expect(EscalationPolicy.afterOnDevice(quiet, message: twoSigns, minWarningSigns: 2) == .patternsDisagree)
        #expect(EscalationPolicy.afterOnDevice(quiet, message: twoSigns, minWarningSigns: 3) == nil)
    }
}
