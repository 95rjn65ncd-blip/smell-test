# Benchmark

Runs 150 labeled, made-up messages through the same on-device first pass the iPhone app uses: the same prompt,
the same answer checks and the same escalation rules, all from [SmellTestCore](../Packages/SmellTestCore).
It runs on the Apple on-device model on a Mac and makes no network calls.

```bash
cd benchmark
swift run -c release smell-bench --repeat 3
```

To look at a few answers while working on the prompt: `--ids l001,s005 --show-raw --out /tmp/bench`.

Needs a Mac with Apple Intelligence turned on (macOS 26 or later). Results go to `results/` as a Markdown report
and a per-message JSONL file, tagged with the date and prompt version.

## What it reports

Each of these is counted separately:

- **Misses:** scam messages that got "No red flags found" with no second opinion offered.
- **False alarms:** messages that aren't scams but got "Scam" or "Likely scam".
- **"Not sure":** an honest answer. The app offers a second opinion.
- **Latency:** time for the on-device model to answer (median and 90th percentile).
- **Cloud calls:** second opinions the app would **offer**. In the app, each one still goes through the Privacy
  Shield and needs the user's OK before anything is sent.

It also lists the threshold sweep for `min_warning_signs`, the Remote Config value that decides when "No red
flags" plus fixed-pattern warning signs triggers a second opinion.

## The messages

[data/messages.jsonl](data/messages.jsonl) has 80 scam messages across the app's scam types and 70 that aren't
scams. Many of the non-scam messages are deliberately tricky: real-looking verification codes, bank alerts,
bills with late fees, sales that "end today", and family texts about hospitals or car trouble. Each message is
marked obvious, subtle, easy or tricky, and has a split: **dev** (odd-numbered, used while tuning the prompt) or
**holdout** (even-numbered, never used while tuning). Report the holdout numbers.

Every message, person, company and link is made up. Don't visit the links.

## Limits

- The messages were written by the developer, not collected from real victims. That can make the set easier
  or harder than real life.
- The prompt was tuned on the dev half, so dev numbers flatter it. The untuned baseline report covered every
  message, so the holdout isn't perfectly untouched.
- It measures the on-device first pass only, not the cloud second opinion.
- It runs on a Mac. The Mac and iPhone use the same Apple on-device model family, but results on an iPhone may
  differ a little.
- The model's answers vary from run to run, so use `--repeat 3` or more for published numbers.
