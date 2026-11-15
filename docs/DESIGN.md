# Design rules

These rules are settled. Code, UI copy, README and the video follow them.

## Verdicts

The verdict is one of exactly four values:

| Value | UI label |
|---|---|
| `scam` | Scam |
| `likely_scam` | Likely scam |
| `not_sure` | Not sure |
| `no_red_flags` | No red flags found |

There is **no "safe" verdict**. The app never tells anyone a message is safe, only that it found no red flags.
On a parse or validation failure the app shows "Couldn't check, try again". It never makes up a verdict.

## Privacy wording

Never claim personal details *cannot* leave the phone. The accurate claim is: **personal details are removed
before anything is sent, and you see exactly what will be sent before it goes.**

## Check flow

1. **First pass, on-device only.** The original text goes only to a session built on the on-device model alone
   (`generativeModelSession(model: SystemLanguageModel.default)`). That session has no cloud path, so the
   original text can never fall back to the cloud.
2. **Escalate** only when the verdict is `not_sure`, the fixed patterns disagree with the model, the input is too
   long for on-device (instructions + input + answer must fit well under 4,096 tokens), the on-device model is
   unavailable, or the user asks for a cloud check of the image.
3. **Redact.** Fixed patterns first (phone, email, card/account numbers, codes, addresses). Then the on-device model
   catches names, if it's available. If the on-device model is unavailable: fixed patterns only, a louder warning,
   and the user can edit the text.
4. **Show** exactly what will be sent, with redactions visible. **Send** / **Cancel**.
5. **Consent.** Nothing is sent without the Send tap.
6. **Hybrid session on the approved text only.** `HybridModel(primary: cloud, secondary: device)` runs only on
   the redacted, user-approved text: cloud first, because a second opinion should come from a different, larger
   model, with the on-device model as the fallback when offline. The cloud-capable function accepts only an
   `ApprovedText`, which only `PrivacyShield.approve` can create, so the original text has no way in.
7. After each check, show "what left your phone": nothing, or the exact redacted text. The original is never logged.

### Tests

- Leak tests depend only on the fixed patterns: no original personal detail ever appears in an outgoing request.
- **An explicit test of the fallback path**: when the on-device model is unavailable, the hybrid session gets only
  approved redacted text, and the original text never reaches any session that has a cloud model.

## Remote Config

Every value is validated in `SmellTestCore/Settings.swift`; anything missing or out of range uses the built-in
default, so a bad console edit can't break checks or loosen the privacy rules.

| Parameter | Default | Rule |
|---|---|---|
| `cloud_model` | `gemini-3.5-flash-lite` | must look like `gemini-…` |
| `second_opinion_enabled` | `true` | kill switch; `false` hides the second opinion and nothing is sent |
| `min_warning_signs` | `2` | 1–5; how many kinds of warning sign make "no red flags" escalate. Benchmark (Nov 15): 1 catches one more scam in 240 checks but offers 9 more unneeded second opinions; 3–5 behave the same as 2 |
| `current_scam_patterns` | empty | one per line, at most 5, 120 characters each; added to the prompt |

There is no auto-send setting. Nothing is ever sent without the Send tap.

## Fixed patterns versus the model

The fixed warning-sign patterns can overrule the on-device model in both directions (`EscalationPolicy.firstPass`):

- The model says "No red flags", but the message has strong warning signs: shown as is, second opinion offered.
- The model says "Scam" or "Likely scam", but the message has none of the warning signs: shown as **"Not sure"**,
  with the model's quotes, fixed wording and fixed steps, and a second opinion offered. Chosen Nov 15 from the
  benchmark: false alarms fell from 22% to 4% (holdout); more scams land on "Not sure" instead of "Scam".

This applies to the on-device first pass only, not to the cloud second opinion.

## Benchmark

Reported separately for on-device and cloud: **misses** (scams not flagged), **false alarms** (legitimate messages
flagged), **"not sure" rate**, **latency** (median time to verdict) and **cloud calls** (made and avoided).
Every number in the README comes from the benchmark script ([benchmark/](../benchmark)).

The answer checks never show a link, phone number or email address the model wrote: a next step containing one is
replaced with a fixed, human-written step, and a summary or reason that mentions contact details not in the
message is rejected. (The first prompt version invented a bank website in a next step.)

## Scope calls

- **Chrome version: decide by Nov 19.** Cut it if judges can't try it easily.
- **Share Extension can slip** if it threatens the core flow.

## Demo story

1. An offline check works on the phone.
2. An honest "Not sure".
3. A redacted second opinion from the cloud, with the preview and consent.
4. A practical next step.
