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
}
