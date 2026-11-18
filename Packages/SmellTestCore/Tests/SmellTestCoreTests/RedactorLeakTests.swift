import Testing
@testable import SmellTestCore

/// Leak tests: every personal detail below is made up. Each case lists the details that must
/// never survive redaction. These tests depend only on the fixed patterns, never on a model.
struct RedactorLeakTests {
    struct Case: CustomStringConvertible {
        let message: String
        let secrets: [String]
        let mustKeep: [String]
        var description: String { String(message.prefix(40)) }
    }

    static let cases: [Case] = [
        Case(message: "ParcelPoint: Your package is on hold. Confirm your address at https://parcelpoint-redelivery.top/track?id=88213945&u=margaret.l@example.com within 24 hours.",
             secrets: ["88213945", "margaret.l@example.com"],
             mustKeep: ["parcelpoint-redelivery.top", "24 hours"]),
        Case(message: "Hi Margaret, this is Northbank Fraud Dept. Your card ending in 4821 was charged $1,249.99. Call us at (555) 201-7788 or reply with the code 662913.",
             secrets: ["Margaret", "4821", "555", "201-7788", "662913"],
             mustKeep: ["$1,249.99", "Northbank"]),
        Case(message: "Grandma it's me, I'm in jail. Please send $2,000 in gift cards to 1438 Willow Creek Drive, Apt 3B, then text +44 7700 900123.",
             secrets: ["1438 Willow Creek", "3B", "7700 900123", "+44"],
             mustKeep: ["$2,000", "gift cards"]),
        Case(message: "Your account number 004417829930 has been locked. Verify your SSN 078-05-1120 and card 4111 1111 1111 1111 at www.secure-verify-login.com/acct/004417829930",
             secrets: ["004417829930", "078-05-1120", "4111 1111 1111 1111", "4111"],
             mustKeep: ["secure-verify-login.com"]),
        Case(message: "Dear Mr. Okafor, your TollWay toll of $6.99 is unpaid. Pay at https://tollway-pay.help/pay#ref=K7Q2X9 or call 1-800-555-0142. Ref A7X9Q2.",
             secrets: ["Okafor", "K7Q2X9", "1-800-555-0142", "800-555-0142", "A7X9Q2"],
             mustKeep: ["$6.99", "tollway-pay.help"]),
        Case(message: "Your CloudKey verification code is 482913. Don't share it. Contact support@help-desk-cloudkey.net. Tracking 1Z999AA10123456784.",
             secrets: ["482913", "support@help-desk-cloudkey.net", "1Z999AA10123456784"],
             mustKeep: ["verification code"]),
        Case(message: "Hey Daniel Reyes! Congrats, you won $5,000. Send your bank acct ...7781 and routing 021000021 to claim.",
             secrets: ["Daniel", "Reyes", "7781", "021000021"],
             mustKeep: ["$5,000"]),
    ]

    @Test(arguments: cases)
    func noSecretSurvives(_ c: Case) {
        let out = Redactor.redact(c.message).text
        for secret in c.secrets {
            #expect(!out.contains(secret), "Leaked \"\(secret)\" in: \(out)")
        }
    }

    @Test(arguments: cases)
    func scamSignalsAreKept(_ c: Case) {
        let out = Redactor.redact(c.message).text
        for keep in c.mustKeep {
            #expect(out.contains(keep), "Dropped signal \"\(keep)\" from: \(out)")
        }
    }

    @Test func plainMessageIsUnchanged() {
        let msg = "Hey, are we still on for lunch Thursday? The new place on Main opens at noon."
        let r = Redactor.redact(msg)
        #expect(r.text == msg)
        #expect(r.totalRedactions == 0)
    }

    @Test func countsAreReported() {
        let r = Redactor.redact("Call 555-201-7788 or email a@b.co")
        #expect(r.counts[.phone] == 1)
        #expect(r.counts[.email] == 1)
    }
}

extension RedactorLeakTests {
    /// Send re-runs the redactor, so redacting twice must change nothing.
    @Test(arguments: cases)
    func redactionIsIdempotent(_ c: Case) {
        let once = Redactor.redact(c.message).text
        let twice = Redactor.redact(once)
        #expect(twice.text == once)
        #expect(twice.totalRedactions == 0, "Second pass changed: \(twice.text)")
    }

    /// Nov 17: the greeting rule turned "Hi Mum" into "Hi [NAME]".
    @Test func greetingKeepsFamilyWords() {
        #expect(Redactor.redact("Hi Mum, it's me").text == "Hi Mum, it's me")
        #expect(Redactor.redact("Hey Dad, new number").text == "Hey Dad, new number")
        #expect(Redactor.redact("Hi Margaret, it's me").text == "Hi [NAME], it's me")
        #expect(Redactor.redact("Dear Mr. Lopez, hello").text == "Dear Mr. [NAME], hello")
    }
}
