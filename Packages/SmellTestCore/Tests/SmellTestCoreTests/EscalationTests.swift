import Testing
@testable import SmellTestCore

struct EscalationTests {
    let scammy = "Final notice: your TollWay account is suspended. Pay the $6.99 fee within 24 hours at https://tollway-pay.help/pay"
    let benign = "Hey, are we still on for lunch Thursday? The new place on Main opens at noon."

    func result(_ v: Verdict) -> CheckResult {
        CheckResult(verdict: v, scamType: .none, summary: "s", reasons: [], nextSteps: ["a", "b", "c"])
    }

    @Test func scannerFindsSignals() {
        #expect(RedFlagScanner.isStrong(RedFlagScanner.scan(scammy)))
        #expect(RedFlagScanner.scan(benign).isEmpty)
    }

    @Test func notSureEscalates() {
        #expect(EscalationPolicy.afterOnDevice(result(.notSure), message: benign) == .modelNotSure)
    }

    @Test func disagreementEscalates() {
        #expect(EscalationPolicy.afterOnDevice(result(.noRedFlags), message: scammy) == .patternsDisagree)
        #expect(EscalationPolicy.afterOnDevice(result(.noRedFlags), message: benign) == nil)
    }

    @Test func confidentVerdictsDoNotEscalate() {
        #expect(EscalationPolicy.afterOnDevice(result(.scam), message: scammy) == nil)
    }

    @Test func longOrUnavailableEscalatesBeforeAnyModelRuns() {
        #expect(EscalationPolicy.preCheck(message: benign, onDeviceAvailable: false) == .onDeviceUnavailable)
        let long = String(repeating: "word ", count: 2_000)  // ~10,000 chars
        #expect(EscalationPolicy.preCheck(message: long, onDeviceAvailable: true) == .tooLongForOnDevice)
        #expect(EscalationPolicy.preCheck(message: benign, onDeviceAvailable: true) == nil)
    }

    @Test func promptFitsWindowWithRoomForAnswer() {
        let maxMsg = String(repeating: "a", count: VerdictPrompt.maxMessageTokens * 3)
        #expect(VerdictPrompt.fitsOnDevice(message: maxMsg))
        #expect(!VerdictPrompt.fitsOnDevice(message: maxMsg + String(repeating: "a", count: 10)))
    }

    @Test func warningWithoutFixedSignsShowsNotSure() {
        let quoted = CheckResult(verdict: .scam, scamType: .romance, summary: "A scam.",
                                 reasons: [Reason(quote: "lunch Thursday", why: "Odd.")], nextSteps: ["Block them.", "b", "c"])
        let (shown, reason) = EscalationPolicy.firstPass(quoted, message: benign)
        #expect(shown.verdict == .notSure)
        #expect(reason == .warningWithoutCommonSigns)
        #expect(shown.reasons == quoted.reasons)
        #expect(shown.nextSteps == SafeSteps.steps(for: .notSure))
    }

    @Test func warningWithFixedSignsIsKept() {
        let (shown, reason) = EscalationPolicy.firstPass(result(.scam), message: scammy)
        #expect(shown.verdict == .scam)
        #expect(reason == nil)
    }

    @Test func firstPassKeepsOtherRules() {
        #expect(EscalationPolicy.firstPass(result(.noRedFlags), message: scammy).escalation == .patternsDisagree)
        #expect(EscalationPolicy.firstPass(result(.notSure), message: benign).escalation == .modelNotSure)
        #expect(EscalationPolicy.firstPass(result(.noRedFlags), message: benign).escalation == nil)
    }

    @Test func newNumberScamEscalatesWhenModelSeesNoRedFlags() {
        let hiMum = "Hi Mum, it's Jess. This is my new number, my old phone broke. Can you message me on WhatsApp here instead? Need to ask you something quickly x"
        #expect(RedFlagScanner.scan(hiMum) == [.impersonation, .channelSwitch])
        #expect(EscalationPolicy.afterOnDevice(result(.noRedFlags), message: hiMum) == .patternsDisagree)
        #expect(RedFlagScanner.scan("Can you text me when you're home? Love, Mum").isEmpty)
    }
}
