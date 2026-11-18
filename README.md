# Smell Test

**A privacy-first scam checker that thinks on your phone first.** By Cognito Agora.

> Work in progress for #BuildHybridAI 2026. This README is filled in as features land; every claim here
> will link to the code that backs it, and every number will come from the published benchmark script.

## Status

- [x] iOS app shell with Firebase AI Logic hybrid inference (`HybridModel`: Apple Foundation Models on-device, Gemini in the cloud)
- [x] Structured verdict (validated JSON), result card, where-it-ran badge, read aloud, "Already clicked?" recovery steps
- [x] Fixed-pattern redactor with leak tests (`cd Packages/SmellTestCore && swift test`)
- [x] Share Extension: checks shared text on the iPhone only ([ios/ShareExtension](ios/ShareExtension))
- [x] Screenshots: words read on the iPhone with Apple's text recognition, then checked like pasted text; the picture never leaves the phone ([ScreenshotReader.swift](ios/SmellTest/ScreenshotReader.swift), [ScreenshotText.swift](Packages/SmellTestCore/Sources/SmellTestCore/ScreenshotText.swift))
- [x] Privacy Shield: fixed patterns + on-device name pass, preview with Send/Cancel, editable, re-checked on Send
- [x] Second opinion through `HybridModel` on approved text only, with "What left your iPhone" shown exactly
- [x] Remote Config with validated defaults
- [ ] Chrome web version
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
([full report](benchmark/results/2026-11-18-prompt-v2-rules-2.md), [how to rerun](benchmark/README.md). Rerun Nov 17 after the
parser started catching copied prompt examples; the Nov 15 run is [here](benchmark/results/2026-11-15-prompt-v2-rules-2.md) and
is within run-to-run noise of it.)

| On-device first pass (holdout) | |
|---|---|
| Scams missed (said "No red flags", no second opinion offered) | 2% |
| Scams flagged as a scam | 82% |
| Ordinary messages wrongly flagged as a scam | 4% |
| "Not sure" (second opinion offered) | 34% of checks |
| Time to answer, median | 2.4 s |

How it got here: the first prompt flagged 64% of ordinary messages as scams
([report](benchmark/results/2026-11-15-prompt-v1.md)). A clearer prompt brought that to 22%
([report](benchmark/results/2026-11-15-prompt-v2.md)). Then a fixed rule: when the model says "Scam" but the
message has none of the usual warning signs, the app says "Not sure" and offers a second opinion instead. That
trades false alarms for honest "Not sure" answers.

## Design

See [docs/DESIGN.md](docs/DESIGN.md) for the verdicts, the privacy wording and the check flow.

## Setup

See [docs/SETUP.md](docs/SETUP.md).

## Built during the submission period

All code in this repository was written from Nov 14, 2026 onward for #BuildHybridAI. It is new code, inspired by
Cognito Agora's existing iPhone app The OPS Detector; no code from that app is included.

## License

[Apache-2.0](LICENSE)
