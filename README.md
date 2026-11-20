# Smell Test

**A privacy-first scam checker that thinks on your phone first.** By Cognito Agora.

Scam texts work because they rush you. Smell Test lets you paste, share or screenshot a message that feels off
and get a plain answer in about two seconds: **Scam**, **Likely scam**, **Not sure** or **No red flags found**,
with the exact words that raised the alarm and three safe next steps. The first check runs entirely on your
iPhone. A larger cloud model only sees the message if you ask for a second opinion, after names, numbers and
links are stripped and you've approved exactly what will be sent.

Built for #BuildHybridAI 2026 with Firebase AI Logic (Apple Foundation Models on-device, Gemini in the cloud).

## How hybrid inference is used

Smell Test uses the two halves of Firebase AI Logic for different jobs, on purpose:

1. **Every check starts on-device only.** The raw message is checked by the Apple on-device model through
   `generativeModelSession(model: SystemLanguageModel)`, with no cloud fallback, so a message that may contain a
   bank code or an address never leaves the phone automatically.
   [CheckEngine.swift:61-63](ios/SmellTest/CheckEngine.swift#L61-L63), `respond` at
   [:68](ios/SmellTest/CheckEngine.swift#L68). Availability is checked before every call
   ([:56-59](ios/SmellTest/CheckEngine.swift#L56-L59)).
2. **Escalate only on doubt.** The app offers a second opinion when the on-device model says "Not sure", when
   fixed scam patterns disagree with it, when the message is too long for the on-device window, or when Apple
   Intelligence is unavailable; never because of the model's own confidence score.
   [Escalation.swift](Packages/SmellTestCore/Sources/SmellTestCore/Escalation.swift)
3. **The Privacy Shield gates the cloud.** Fixed patterns plus an on-device name pass remove personal details;
   the user sees and can edit exactly what will be sent, and nothing goes until they tap Send. The cloud path
   only accepts an `ApprovedText`, which can only be built by that approval.
   [PrivacyShield.swift](Packages/SmellTestCore/Sources/SmellTestCore/PrivacyShield.swift)
4. **The second opinion is `HybridModel(primary: cloud, secondary: device)`**, so the larger Gemini model
   answers when online and the on-device model still answers offline.
   [CheckEngine.swift:126-135](ios/SmellTest/CheckEngine.swift#L126-L135)
5. **Protected and remotely controlled.** App Check with App Attest and limited-use tokens
   ([SmellTestApp.swift:19-21](ios/SmellTest/SmellTestApp.swift#L19-L21),
   [CheckEngine.swift:126](ios/SmellTest/CheckEngine.swift#L126)); Remote Config holds the cloud model name, a
   kill switch for second opinions, the escalation threshold and current scam patterns
   ([RemoteSettings.swift](ios/SmellTest/RemoteSettings.swift)).

## Status

- [x] iOS app shell with Firebase AI Logic hybrid inference (`HybridModel`: Apple Foundation Models on-device, Gemini in the cloud)
- [x] Structured verdict (validated JSON), result card, where-it-ran badge, read aloud, "Already clicked?" recovery steps
- [x] Fixed-pattern redactor with leak tests (`cd Packages/SmellTestCore && swift test`)
- [x] Share Extension: checks shared text on the iPhone only ([ios/ShareExtension](ios/ShareExtension))
- [x] Screenshots: words read on the iPhone with Apple's text recognition, then checked like pasted text; the picture never leaves the phone ([ScreenshotReader.swift](ios/SmellTest/ScreenshotReader.swift), [ScreenshotText.swift](Packages/SmellTestCore/Sources/SmellTestCore/ScreenshotText.swift))
- [x] Privacy Shield: fixed patterns + on-device name pass, preview with Send/Cancel, editable, re-checked on Send
- [x] Second opinion through `HybridModel` on approved text only, with "What left your iPhone" shown exactly
- [x] Remote Config with validated defaults
- [x] Chrome web version: https://iossmelltest.web.app/check (desktop Chrome with its built-in model; same rules as the iPhone, tested against Swift with 169 parity tests)
- [x] Benchmark: 150 made-up messages, rerunnable on a Mac ([benchmark/](benchmark))

## Where Firebase AI Logic is called

| What | File |
|---|---|
| `HybridModel(primary: cloud, secondary: device)` second opinion, on Privacy Shield–approved text only | [ios/SmellTest/CheckEngine.swift](ios/SmellTest/CheckEngine.swift) (`secondOpinion`) |
| Privacy Shield and the `ApprovedText` gate | [Packages/SmellTestCore/Sources/SmellTestCore/PrivacyShield.swift](Packages/SmellTestCore/Sources/SmellTestCore/PrivacyShield.swift) |
| Hello-world hybrid smoke test (debug diagnostics) | [ios/SmellTest/HelloHybridView.swift](ios/SmellTest/HelloHybridView.swift) |
| On-device-only first pass of every check (no cloud path) | [ios/SmellTest/CheckEngine.swift](ios/SmellTest/CheckEngine.swift) |
| Verdict schema, validation, redactor, escalation rules (no network code) | [Packages/SmellTestCore](Packages/SmellTestCore) |
| Remote Config (cloud model, kill switch, escalation threshold, current scam patterns) | [ios/SmellTest/RemoteSettings.swift](ios/SmellTest/RemoteSettings.swift), validated in [Settings.swift](Packages/SmellTestCore/Sources/SmellTestCore/Settings.swift) |
| App Check (debug provider / App Attest) | [ios/SmellTest/SmellTestApp.swift](ios/SmellTest/SmellTestApp.swift) |

## Benchmark

150 made-up messages (80 scams, 70 ordinary messages, many deliberately tricky), 3 runs each, on the Apple
on-device model. These are first-pass numbers before any second opinion. The prompt was tuned on half the messages;
these are from the other half, which wasn't used while tuning.
([full report](benchmark/results/2026-11-20-prompt-v2-rules-3.md), [how to rerun](benchmark/README.md). Rules 3 added the
"family member with a new number" and "move the chat elsewhere" warning signs; they match no ordinary message in the
set, so the false-alarm change from the [rules-2 run](benchmark/results/2026-11-18-prompt-v2-rules-2.md) (4% to 6%) is
run-to-run noise from the model.)

| On-device first pass (holdout) | |
|---|---|
| Scams missed (said "No red flags", no second opinion offered) | 1% |
| Scams flagged as a scam | 83% |
| Ordinary messages wrongly flagged as a scam | 6% |
| "Not sure" (second opinion offered) | 30% of checks |
| Time to answer, median | 2.5 s |

How it got here: the first prompt flagged 64% of ordinary messages as scams
([report](benchmark/results/2026-11-15-prompt-v1.md)). A clearer prompt brought that to 22%
([report](benchmark/results/2026-11-15-prompt-v2.md)). Then a fixed rule: when the model says "Scam" but the
message has none of the usual warning signs, the app says "Not sure" and offers a second opinion instead. That
trades false alarms for honest "Not sure" answers.

**Not measured yet:** these are on-device numbers only. The benchmark doesn't yet run the cloud second opinion, so
there are no cloud accuracy or latency numbers, and "cloud calls avoided" is only implied (the 70% of checks that
weren't "Not sure" never offered one). The prompt version is compiled into the app (`VerdictPrompt.version`), not
switchable from Remote Config.

## Design

See [docs/DESIGN.md](docs/DESIGN.md) for the verdicts, the privacy wording and the check flow.

## Setup

See [docs/SETUP.md](docs/SETUP.md).

## Built during the submission period

All code in this repository was written from Nov 14, 2026 onward for #BuildHybridAI. It is new code, inspired by
Cognito Agora's existing iPhone app The OPS Detector; no code from that app is included.

## License

[Apache-2.0](LICENSE)
