import Testing
@testable import SmellTestCore

struct PrivacyShieldTests {
    @Test(arguments: RedactorLeakTests.cases)
    func approvedTextNeverContainsSecrets(_ c: RedactorLeakTests.Case) throws {
        // Fallback path: the on-device model is unavailable, so names are unchecked (nil).
        let preview = PrivacyShield.preview(original: c.message, names: nil)
        let approved = try PrivacyShield.approve(shownText: preview.text, namesChecked: preview.namesChecked)
        for secret in c.secrets {
            #expect(!approved.text.contains(secret), "Leaked \"\(secret)\" in: \(approved.text)")
        }
    }

    @Test func fallbackPathIsFlaggedForReview() {
        let preview = PrivacyShield.preview(original: "Margaret, call 555-201-7788", names: nil)
        #expect(!preview.namesChecked)
        #expect(!preview.text.contains("555-201-7788"))
    }

    @Test func detailsTypedWhileEditingAreCaught() {
        #expect(throws: PrivacyShield.ApprovalProblem.self) {
            try PrivacyShield.approve(shownText: "Pay now. My number is 555-201-7788", namesChecked: true)
        }
    }

    @Test func emptyIsRejected() {
        #expect(throws: PrivacyShield.ApprovalProblem.empty) {
            try PrivacyShield.approve(shownText: "   ", namesChecked: true)
        }
    }

    @Test func namesFromOnDeviceModelAreReplaced() throws {
        let preview = PrivacyShield.preview(
            original: "Grandma, it's Tommy. Uncle Ray said to ask Daniel Reyes for the money.",
            names: ["Tommy", "Ray", "Daniel Reyes"])
        #expect(preview.namesChecked)
        for name in ["Tommy", "Ray", "Daniel", "Reyes"] { #expect(!preview.text.contains(name)) }
        #expect(preview.text.contains("Grandma"))
        #expect(preview.counts[.name] == 3)
        // Labels must survive approval unchanged.
        let approved = try PrivacyShield.approve(shownText: preview.text, namesChecked: true)
        #expect(approved.text == preview.text)
    }

    @Test func nameReplacementDoesNotTouchOtherWords() {
        let out = PrivacyShield.replaceNames(in: "Ray sent a ray of hope; Bray Street", names: ["Ray"]).text
        #expect(out == "[NAME] sent a [NAME] of hope; Bray Street")  // case-insensitive, whole words only
    }

    @Test func parsesNameOutput() {
        #expect(PrivacyShield.parseNames("Here you go: [\"Ana\", \"Mr. Lee\"]") == ["Ana", "Mr. Lee"])
        #expect(PrivacyShield.parseNames("[]") == [])
        #expect(PrivacyShield.parseNames("no names") == nil)
    }
}
