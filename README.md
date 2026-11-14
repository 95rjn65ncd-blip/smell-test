# Smell Test

**A privacy-first scam checker that thinks on your phone first.** By Cognito Agora.

> Work in progress for #BuildHybridAI 2026. This README is filled in as features land; every claim here
> will link to the code that backs it, and every number will come from the published benchmark script.

## Status

- [x] iOS app shell with Firebase AI Logic hybrid inference (`HybridModel`: Apple Foundation Models on-device, Gemini in the cloud)
- [x] Structured verdict (validated JSON), result card, where-it-ran badge, read aloud, "Already clicked?" recovery steps
- [x] Fixed-pattern redactor with leak tests (`cd Packages/SmellTestCore && swift test`)
- [ ] Share Extension
- [ ] Privacy Shield (redaction before anything leaves the phone)
- [ ] Second opinion when the on-device result is unclear
- [ ] Chrome web version
- [ ] Benchmark

## Where Firebase AI Logic is called

| What | File |
|---|---|
| `HybridModel(primary: device, secondary: cloud)` and `generativeModelSession` | [ios/SmellTest/HelloHybridView.swift](ios/SmellTest/HelloHybridView.swift) |
| On-device-only first pass of every check (no cloud path) | [ios/SmellTest/CheckEngine.swift](ios/SmellTest/CheckEngine.swift) |
| Verdict schema, validation, redactor, escalation rules (no network code) | [Packages/SmellTestCore](Packages/SmellTestCore) |
| App Check (debug provider / App Attest) | [ios/SmellTest/SmellTestApp.swift](ios/SmellTest/SmellTestApp.swift) |

## Design

See [docs/DESIGN.md](docs/DESIGN.md) for the verdicts, the privacy wording and the check flow.

## Setup

See [docs/SETUP.md](docs/SETUP.md).

## Built during the submission period

All code in this repository was written from Nov 14, 2026 onward for #BuildHybridAI. It is new code, inspired by
Cognito Agora's existing iPhone app The OPS Detector; no code from that app is included.

## License

[Apache-2.0](LICENSE)
