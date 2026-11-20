# Devpost description (DRAFT — Eric submits it himself)

Paste each section into the matching Devpost field. Every scam example, person and company is made up.
Numbers come from the newest benchmark report; check them against `benchmark/results/` before pasting.

## Tagline

A privacy-first scam checker that thinks on your phone first.

## Inspiration

Scam texts work because they rush you: a parcel fee due in 12 hours, a bank account "locked today", a "Hi Mum,
new number" message from someone who sounds like your kid. The people most likely to be caught are often the
least likely to paste a private message into a chatbot, and they're right to hesitate. A message about money
often contains a bank code, an address or a name. We wanted a second pair of eyes that keeps those details on
the phone unless you decide otherwise.

## What it does

Paste, share or screenshot a message that feels off. In about two seconds Smell Test gives a plain answer:
**Scam**, **Likely scam**, **Not sure** or **No red flags found**. It never says "safe". It shows the exact
words that raised the alarm, three safe next steps, and, if you already clicked, paid or shared, recovery steps.

The first check runs entirely on the device: Apple's on-device model on iPhone, or Chrome's built-in model on a
desktop computer. When the device isn't sure, or when fixed warning-sign checks disagree with it, Smell Test
offers a second opinion from Gemini in the cloud. Before anything is sent, the Privacy Shield removes names, phone
numbers, emails, account numbers and links, shows you exactly what will be sent, and lets you edit it. Nothing
leaves until you tap Send, and afterwards the iPhone app shows exactly what left.

- iPhone app (iOS 26, Apple Intelligence): paste, share sheet, screenshots read on-device, read-aloud.
- Chrome version: https://iossmelltest.web.app/check, same rules as the iPhone, tested against the Swift code.

## How we built it: Firebase AI Logic hybrid inference

We use the two halves of hybrid inference for different jobs, on purpose:

1. **On-device only for the raw message.** Every check starts with an on-device-only session
   (`generativeModelSession` with `SystemLanguageModel` on iOS; `ONLY_ON_DEVICE` in Chrome). There is no
   automatic cloud fallback for the raw text, and availability is checked before every call.
2. **Escalate on doubt, never on confidence.** A second opinion is offered when the model says "Not sure", when
   fixed warning-sign patterns disagree with its answer, when the message is too long for the on-device window,
   or when the on-device model isn't available. The small model's own confidence is never used.
3. **The Privacy Shield gates the cloud.** Fixed patterns plus an on-device name pass redact the text. The cloud
   path only accepts an `ApprovedText`, which can only be created by the user's approval in the preview.
4. **The second opinion is `HybridModel(primary: cloud, secondary: device)`** (`PREFER_IN_CLOUD` in Chrome), so
   Gemini answers when online and the device still answers offline. The badge shows where each answer came from.
5. **Protected and tunable.** App Check (App Attest on iPhone, reCAPTCHA Enterprise on the web) with limited-use
   tokens; Remote Config holds the cloud model name, a kill switch, the escalation threshold and current scam
   patterns.

The shared rules (prompt, answer validation, redactor, escalation) live in a Swift package with no network code.
The Chrome version imports the same prompt text generated from Swift and runs a parity test suite against
Swift's own answers, so the two can't drift.

## Benchmark

150 made-up messages (80 scams, 70 ordinary messages, many deliberately tricky), 3 runs each on the on-device
model. The prompt was tuned on half the messages; these numbers are from the other half
(benchmark/results/2026-11-20-prompt-v2-rules-3.md).

| On-device first pass (holdout) | |
|---|---|
| Scams missed (no warning and no second opinion) | 1% |
| Scams flagged as a scam | 83% |
| Ordinary messages wrongly flagged | 6% |
| "Not sure" (second opinion offered) | 30% of checks |
| Time to answer, median | 2.5 s |

The first prompt flagged 64% of ordinary messages as scams. A clearer prompt, plus a rule that turns "Scam" into
"Not sure" when the message has none of the usual warning signs, brought false alarms down to single digits by
trading them for honest "Not sure" answers.

## Challenges

- A small on-device model is eager to call everything a scam. Measuring misses, false alarms and "not sure"
  separately, on a held-out set, kept us honest about the trade-offs.
- "Hi Mum, new number" scams have no link, no money and no urgency in the first message. We added fixed warning
  signs for a family member with a new number and for moving the chat to another app.
- Redaction must not remove the scam signal itself: "Mum", "Dad" and similar words stay, real names go.

## Accomplishments

- The raw message never leaves the device unless the user reads and approves the redacted version.
- One set of rules on two platforms, enforced by tests.
- Submitted to the App Store.

## What we learned

Hybrid inference is most useful when each side has a clear job: the device for privacy and speed, the cloud for
the hard cases, and a person in between.

## What's next

Run the benchmark against the cloud second opinion, add more languages, and let users report scams that slipped
through so Remote Config patterns can be updated quickly.

## Built with

Firebase AI Logic, Gemini, Apple Foundation Models, Chrome built-in AI, Firebase App Check, Firebase Remote
Config, Firebase Hosting, Swift, SwiftUI, JavaScript, Vite.

## Built during the submission period

All code was written from Nov 14, 2026 onward for #BuildHybridAI. It's new code, inspired by Cognito Agora's
existing iPhone app The OPS Detector; no code from that app is included.
