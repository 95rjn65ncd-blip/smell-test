# Smell Test benchmark: 2026-11-18

- Messages: 150 made-up messages (80 scam, 70 not scam), 3 run(s) each
- Model: Apple on-device model on this Mac (Version 26.7.3 (Build 25G416)), guardrails `.permissiveContentTransformations`
- Prompt: `v2`, escalation rules: `2`; same prompt, parser and escalation rules as the iPhone app
- "Cloud calls" are second opinions the app would **offer**. Each still needs the Privacy Shield and the user's OK.
- This run measures the on-device first pass only. It does not measure the cloud second opinion.
- The prompt was tuned using only the **dev** messages (odd-numbered). The **holdout** messages (even-numbered)
  were never used while tuning, so the holdout column is the fairest estimate. (The first, untuned baseline
  report covered every message, so the holdout isn't perfectly untouched, but no holdout message's answer was
  read while writing the prompt.)

## Summary (threshold 2)

| | All (450) | Dev (225) | Holdout (225) |
|---|---|---|---|
| **Scams missed** | 6 (2%) | 3 (2%) | 3 (2%) |
| Scams caught | 172 (72%) | 73 (61%) | 99 (82%) |
| **False alarms** | 17 (8%) | 13 (12%) | 4 (4%) |
| "Not sure" (all messages) | 173 (38%) | 97 (43%) | 76 (34%) |
| Cloud calls offered | 176 (39%) | 99 (44%) | 77 (34%) |
| On-device time, median | 2438 ms | 2423 ms | 2447 ms |
| On-device time, 90th percentile | 3092 ms | 3186 ms | 3080 ms |

## Holdout detail

| Scam messages (120) | Count |
|---|---|
| Caught (scam or likely scam) | 99 (82%) |
| "Not sure", second opinion offered | 17 (14%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **3 (2%)** |
| Phone couldn't answer, second opinion offered | 1 (1%) |

| Not-scam messages (105) | Count |
|---|---|
| "No red flags found" | 42 (40%) |
| **False alarm** (scam or likely scam) | **4 (4%)** |
| "Not sure", second opinion offered | 59 (56%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| Phone couldn't answer, second opinion offered | 0 (0%) |

## All messages detail

| Scam messages (240) | Count |
|---|---|
| Caught (scam or likely scam) | 172 (72%) |
| "Not sure", second opinion offered | 60 (25%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **6 (2%)** |
| Phone couldn't answer, second opinion offered | 2 (1%) |

| Not-scam messages (210) | Count |
|---|---|
| "No red flags found" | 79 (38%) |
| **False alarm** (scam or likely scam) | **17 (8%)** |
| "Not sure", second opinion offered | 113 (54%) |
| "No red flags" but warning signs, second opinion offered | 1 (0%) |
| Phone couldn't answer, second opinion offered | 0 (0%) |

## Threshold sweep (all messages)

How the warning-sign threshold (`min_warning_signs`) trades misses for cloud calls. The model's answers are the same in every row; only the escalation rule changes.

| Threshold | Scams missed | Scams offered a second opinion | Not-scam offered a second opinion | Cloud calls offered |
|---|---|---|---|---|
| 1 | 2 (1%) | 66 (28%) | 125 (60%) | 191 (42%) |
| 2 (current) | 6 (2%) | 62 (26%) | 114 (54%) | 176 (39%) |
| 3 | 6 (2%) | 62 (26%) | 113 (54%) | 175 (39%) |
| 4 | 6 (2%) | 62 (26%) | 113 (54%) | 175 (39%) |
| 5 | 6 (2%) | 62 (26%) | 113 (54%) | 175 (39%) |

## Effect of the "no usual warning signs" rule

When the model says "Scam" or "Likely scam" but the message has none of the fixed warning signs, the app
shows "Not sure" and offers a second opinion. Without that rule, 49 (23%) of
ordinary messages would have been flagged as scams. The rule moved 32 (15%)
of ordinary messages and 53 (22%) of scams to "Not sure".

## Details

### Scams missed at the current threshold

- `s020` (package_delivery, subtle, holdout): 2 of 3 runs
- `s053` (prize, subtle, dev): 1 of 3 runs
- `s065` (family_emergency, subtle, dev): 1 of 3 runs
- `s021` (package_delivery, subtle, dev): 1 of 3 runs
- `s074` (other, subtle, holdout): 1 of 3 runs

### False alarms

- `l003` (verification_code, tricky, dev): 3 of 3 runs
- `l021` (appointment, tricky, dev): 3 of 3 runs
- `l027` (family_friends, tricky, dev): 3 of 3 runs
- `l065` (account, tricky, dev): 2 of 3 runs
- `l066` (account, tricky, holdout): 3 of 3 runs
- `l029` (family_friends, tricky, dev): 1 of 3 runs
- `l055` (marketing, tricky, dev): 1 of 3 runs
- `l006` (bank_alert, tricky, holdout): 1 of 3 runs

### Couldn't answer

- `s075` (other, subtle, dev): 1 of 3 runs
- `s032` (romance, subtle, holdout): 1 of 3 runs

Reasons the phone couldn't answer: `malformedJSON` × 1, `noJSON` × 1

Messages: [data/messages.jsonl](../data/messages.jsonl). Per-message results: [2026-11-18-prompt-v2-rules-2.jsonl](2026-11-18-prompt-v2-rules-2.jsonl).
