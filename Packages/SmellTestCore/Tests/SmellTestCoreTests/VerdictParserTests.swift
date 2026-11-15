import Testing
@testable import SmellTestCore

struct VerdictParserTests {
    let message = "ParcelPoint: Your package is on hold. Pay the $1.99 redelivery fee at parcelpoint-redelivery.top within 24 hours."

    func json(verdict: String = "scam", scamType: String = "package_delivery",
              quote: String = "Pay the $1.99 redelivery fee", steps: Int = 3) -> String {
        let stepList = (0..<steps).map { "\"Step \($0 + 1)\"" }.joined(separator: ",")
        return """
        {"verdict":"\(verdict)","scam_type":"\(scamType)","summary":"This looks like a fake delivery text.",
         "reasons":[{"quote":"\(quote)","why":"Real carriers don't ask for fees by text."}],
         "next_steps":[\(stepList)]}
        """
    }

    @Test func parsesValidOutput() throws {
        let r = try VerdictParser.parse(json(), message: message)
        #expect(r.verdict == .scam)
        #expect(r.scamType == .packageDelivery)
        #expect(r.reasons.count == 1)
        #expect(r.nextSteps.count == 3)
    }

    @Test func toleratesCodeFenceAndProse() throws {
        let wrapped = "Sure! Here is the result:\n```json\n\(json())\n```\nHope that helps."
        #expect(try VerdictParser.parse(wrapped, message: message).verdict == .scam)
    }

    @Test func rejectsSafeVerdict() {
        #expect(throws: VerdictParser.Failure.unknownVerdict("safe")) {
            try VerdictParser.parse(json(verdict: "safe"), message: message)
        }
    }

    @Test func dropsInventedQuotesAndRejectsUnbackedWarning() {
        #expect(throws: VerdictParser.Failure.warningWithoutEvidence) {
            try VerdictParser.parse(json(quote: "send your password now"), message: message)
        }
    }

    @Test func noRedFlagsNeedsNoQuote() throws {
        let r = try VerdictParser.parse(json(verdict: "no_red_flags", quote: "made up"), message: message)
        #expect(r.verdict == .noRedFlags)
        #expect(r.reasons.isEmpty)
        #expect(r.scamType == ScamType.none)
    }

    @Test func requiresExactlyThreeSteps() {
        #expect(throws: VerdictParser.Failure.wrongNumberOfSteps(2)) {
            try VerdictParser.parse(json(steps: 2), message: message)
        }
    }

    @Test func rejectsGarbage() {
        #expect(throws: VerdictParser.Failure.noJSON) {
            try VerdictParser.parse("I think this is a scam.", message: message)
        }
        #expect(throws: VerdictParser.Failure.malformedJSON) {
            try VerdictParser.parse("{\"verdict\": }", message: message)
        }
    }

    @Test func quoteMatchIgnoresCaseAndCurlyQuotes() throws {
        let msg = "Don\u{2019}t miss out \u{2014} ACT NOW to claim your prize."
        let out = json(verdict: "likely_scam", scamType: "prize", quote: "don't miss out")
        #expect(try VerdictParser.parse(out, message: msg).reasons.count == 1)
    }

    @Test func stepsNeverContainLinksOrNumbers() throws {
        let out = """
        {"verdict":"scam","scam_type":"package_delivery","summary":"This looks like a fake delivery text.",
         "reasons":[{"quote":"Pay the $1.99 redelivery fee","why":"Real carriers don't ask for fees by text."}],
         "next_steps":["Go to www.parcelpoint-help.com to check.","Call 555-201-3344 to report it.","Delete the message."]}
        """
        let r = try VerdictParser.parse(out, message: message)
        #expect(r.nextSteps.count == 3)
        #expect(r.nextSteps.allSatisfy { !ContactDetails.contains($0) })
        #expect(r.nextSteps[2] == "Delete the message.")
    }

    @Test func rejectsInventedContactInSummary() {
        let out = json().replacingOccurrences(of: "This looks like a fake delivery text.",
                                              with: "Check at parcelpoint.com instead.")
        #expect(throws: VerdictParser.Failure.inventedContactDetails) {
            try VerdictParser.parse(out, message: message)
        }
    }

    @Test func allowsContactFromMessageInSummary() throws {
        let out = json().replacingOccurrences(of: "This looks like a fake delivery text.",
                                              with: "The link parcelpoint-redelivery.top is not the real carrier.")
        #expect(try VerdictParser.parse(out, message: message).verdict == .scam)
    }

    @Test func stringReasonsCannotBackAWarning() {
        let out = json().replacingOccurrences(of: #"[{"quote":"Pay the $1.99 redelivery fee","why":"Real carriers don't ask for fees by text."}]"#,
                                              with: #"["Asks for a fee"]"#)
        #expect(throws: VerdictParser.Failure.warningWithoutEvidence) {
            try VerdictParser.parse(out, message: message)
        }
    }

    @Test func fixedStepsAreSafe() {
        for v in Verdict.allCases { #expect(SafeSteps.steps(for: v).allSatisfy { !ContactDetails.contains($0) }) }
    }

    @Test func dropsRedFlagNumbering() throws {
        let out = json().replacingOccurrences(of: "Real carriers don't ask for fees by text.",
                                              with: "Asks for a fee to receive something (red flag 1).")
        #expect(try VerdictParser.parse(out, message: message).reasons[0].why == "Asks for a fee to receive something.")
        for tag in ["(scam type 5)", "(red flags 1 and 4)", "(flag 2, 3)"] {
            let o = json().replacingOccurrences(of: "Real carriers don't ask for fees by text.", with: "A fee \(tag).")
            #expect(try VerdictParser.parse(o, message: message).reasons[0].why == "A fee.")
        }
    }
}
