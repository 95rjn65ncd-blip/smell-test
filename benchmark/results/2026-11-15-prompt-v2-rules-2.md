# Smell Test benchmark: 2026-11-15

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
| **Scams missed** | 3 (1%) | 1 (1%) | 2 (2%) |
| Scams caught | 170 (71%) | 70 (58%) | 100 (83%) |
| **False alarms** | 15 (7%) | 11 (10%) | 4 (4%) |
| "Not sure" (all messages) | 165 (37%) | 95 (42%) | 70 (31%) |
| Cloud calls offered | 170 (38%) | 98 (44%) | 72 (32%) |
| On-device time, median | 2450 ms | 2467 ms | 2421 ms |
| On-device time, 90th percentile | 3026 ms | 3058 ms | 2942 ms |

## Holdout detail

| Scam messages (120) | Count |
|---|---|
| Caught (scam or likely scam) | 100 (83%) |
| "Not sure", second opinion offered | 16 (13%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **2 (2%)** |
| Phone couldn't answer, second opinion offered | 2 (2%) |

| Not-scam messages (105) | Count |
|---|---|
| "No red flags found" | 47 (45%) |
| **False alarm** (scam or likely scam) | **4 (4%)** |
| "Not sure", second opinion offered | 54 (51%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| Phone couldn't answer, second opinion offered | 0 (0%) |

## All messages detail

| Scam messages (240) | Count |
|---|---|
| Caught (scam or likely scam) | 170 (71%) |
| "Not sure", second opinion offered | 62 (26%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **3 (1%)** |
| Phone couldn't answer, second opinion offered | 5 (2%) |

| Not-scam messages (210) | Count |
|---|---|
| "No red flags found" | 92 (44%) |
| **False alarm** (scam or likely scam) | **15 (7%)** |
| "Not sure", second opinion offered | 103 (49%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| Phone couldn't answer, second opinion offered | 0 (0%) |

## Threshold sweep (all messages)

How the warning-sign threshold (`min_warning_signs`) trades misses for cloud calls. The model's answers are the same in every row; only the escalation rule changes.

| Threshold | Scams missed | Scams offered a second opinion | Not-scam offered a second opinion | Cloud calls offered |
|---|---|---|---|---|
| 1 | 1 (0%) | 69 (29%) | 114 (54%) | 183 (41%) |
| 2 (current) | 3 (1%) | 67 (28%) | 103 (49%) | 170 (38%) |
| 3 | 3 (1%) | 67 (28%) | 103 (49%) | 170 (38%) |
| 4 | 3 (1%) | 67 (28%) | 103 (49%) | 170 (38%) |
| 5 | 3 (1%) | 67 (28%) | 103 (49%) | 170 (38%) |

## Effect of the "no usual warning signs" rule

When the model says "Scam" or "Likely scam" but the message has none of the fixed warning signs, the app
shows "Not sure" and offers a second opinion. Without that rule, 42 (20%) of
ordinary messages would have been flagged as scams. The rule moved 27 (13%)
of ordinary messages and 56 (23%) of scams to "Not sure".

## Details

### Scams missed at the current threshold

- `s020` (package_delivery, subtle, holdout): 2 of 3 runs
- `s057` (crypto, subtle, dev): 1 of 3 runs

### False alarms

- `l003` (verification_code, tricky, dev): 3 of 3 runs
- `l006` (bank_alert, tricky, holdout): 2 of 3 runs
- `l021` (appointment, tricky, dev): 2 of 3 runs
- `l027` (family_friends, tricky, dev): 3 of 3 runs
- `l065` (account, tricky, dev): 3 of 3 runs
- `l066` (account, tricky, holdout): 2 of 3 runs

### Couldn't answer

- `s045` (tech_support, obvious, dev): 1 of 3 runs
- `s018` (package_delivery, subtle, holdout): 1 of 3 runs
- `s021` (package_delivery, subtle, dev): 1 of 3 runs
- `s034` (romance, subtle, holdout): 1 of 3 runs
- `s071` (other, subtle, dev): 1 of 3 runs

Reasons the phone couldn't answer: `noJSON` × 4, `wrongNumberOfSteps(1)` × 1

Messages: [data/messages.jsonl](../data/messages.jsonl). Per-message results: [2026-11-15-prompt-v2-rules-2.jsonl](2026-11-15-prompt-v2-rules-2.jsonl).
