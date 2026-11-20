# Smell Test benchmark: 2026-11-20

- Messages: 150 made-up messages (80 scam, 70 not scam), 3 run(s) each
- Model: Apple on-device model on this Mac (Version 26.7.3 (Build 25G416)), guardrails `.permissiveContentTransformations`
- Prompt: `v2`, escalation rules: `3`; same prompt, parser and escalation rules as the iPhone app
- "Cloud calls" are second opinions the app would **offer**. Each still needs the Privacy Shield and the user's OK.
- This run measures the on-device first pass only. It does not measure the cloud second opinion.
- The prompt was tuned using only the **dev** messages (odd-numbered). The **holdout** messages (even-numbered)
  were never used while tuning, so the holdout column is the fairest estimate. (The first, untuned baseline
  report covered every message, so the holdout isn't perfectly untouched, but no holdout message's answer was
  read while writing the prompt.)

## Summary (threshold 2)

| | All (450) | Dev (225) | Holdout (225) |
|---|---|---|---|
| **Scams missed** | 3 (1%) | 2 (2%) | 1 (1%) |
| Scams caught | 176 (73%) | 76 (63%) | 100 (83%) |
| **False alarms** | 17 (8%) | 11 (10%) | 6 (6%) |
| "Not sure" (all messages) | 153 (34%) | 86 (38%) | 67 (30%) |
| Cloud calls offered | 159 (35%) | 90 (40%) | 69 (31%) |
| On-device time, median | 2521 ms | 2580 ms | 2453 ms |
| On-device time, 90th percentile | 3242 ms | 3259 ms | 3176 ms |

## Holdout detail

| Scam messages (120) | Count |
|---|---|
| Caught (scam or likely scam) | 100 (83%) |
| "Not sure", second opinion offered | 18 (15%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **1 (1%)** |
| Phone couldn't answer, second opinion offered | 1 (1%) |

| Not-scam messages (105) | Count |
|---|---|
| "No red flags found" | 49 (47%) |
| **False alarm** (scam or likely scam) | **6 (6%)** |
| "Not sure", second opinion offered | 49 (47%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| Phone couldn't answer, second opinion offered | 1 (1%) |

## All messages detail

| Scam messages (240) | Count |
|---|---|
| Caught (scam or likely scam) | 176 (73%) |
| "Not sure", second opinion offered | 57 (24%) |
| "No red flags" but warning signs, second opinion offered | 0 (0%) |
| **Missed** ("No red flags", nothing offered) | **3 (1%)** |
| Phone couldn't answer, second opinion offered | 4 (2%) |

| Not-scam messages (210) | Count |
|---|---|
| "No red flags found" | 95 (45%) |
| **False alarm** (scam or likely scam) | **17 (8%)** |
| "Not sure", second opinion offered | 96 (46%) |
| "No red flags" but warning signs, second opinion offered | 1 (0%) |
| Phone couldn't answer, second opinion offered | 1 (0%) |

## Threshold sweep (all messages)

How the warning-sign threshold (`min_warning_signs`) trades misses for cloud calls. The model's answers are the same in every row; only the escalation rule changes.

| Threshold | Scams missed | Scams offered a second opinion | Not-scam offered a second opinion | Cloud calls offered |
|---|---|---|---|---|
| 1 | 2 (1%) | 62 (26%) | 112 (53%) | 174 (39%) |
| 2 (current) | 3 (1%) | 61 (25%) | 98 (47%) | 159 (35%) |
| 3 | 3 (1%) | 61 (25%) | 97 (46%) | 158 (35%) |
| 4 | 3 (1%) | 61 (25%) | 97 (46%) | 158 (35%) |
| 5 | 3 (1%) | 61 (25%) | 97 (46%) | 158 (35%) |
| 6 | 3 (1%) | 61 (25%) | 97 (46%) | 158 (35%) |

## Effect of the "no usual warning signs" rule

When the model says "Scam" or "Likely scam" but the message has none of the fixed warning signs, the app
shows "Not sure" and offers a second opinion. Without that rule, 46 (22%) of
ordinary messages would have been flagged as scams. The rule moved 29 (14%)
of ordinary messages and 50 (21%) of scams to "Not sure".

## Details

### Scams missed at the current threshold

- `s021` (package_delivery, subtle, dev): 1 of 3 runs
- `s034` (romance, subtle, holdout): 1 of 3 runs
- `s057` (crypto, subtle, dev): 1 of 3 runs

### False alarms

- `l006` (bank_alert, tricky, holdout): 3 of 3 runs
- `l021` (appointment, tricky, dev): 2 of 3 runs
- `l027` (family_friends, tricky, dev): 3 of 3 runs
- `l065` (account, tricky, dev): 3 of 3 runs
- `l066` (account, tricky, holdout): 3 of 3 runs
- `l003` (verification_code, tricky, dev): 2 of 3 runs
- `l029` (family_friends, tricky, dev): 1 of 3 runs

### Couldn't answer

- `s029` (romance, subtle, dev): 1 of 3 runs
- `s068` (family_emergency, subtle, holdout): 1 of 3 runs
- `l044` (receipt, tricky, holdout): 1 of 3 runs
- `s073` (other, subtle, dev): 1 of 3 runs
- `s075` (other, subtle, dev): 1 of 3 runs

Reasons the phone couldn't answer: `malformedJSON` × 1, `noJSON` × 2, `wrongNumberOfSteps(1)` × 2

Messages: [data/messages.jsonl](../data/messages.jsonl). Per-message results: [2026-11-20-prompt-v2-rules-3.jsonl](2026-11-20-prompt-v2-rules-3.jsonl).
