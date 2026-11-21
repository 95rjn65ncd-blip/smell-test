# Submission checklist (#BuildHybridAI 2026)

Deadline: **Nov 30, 2026, 2:00 pm PT**. Target: **Nov 29**. Nothing is pushed after the deadline.
Tick an item only with evidence next to it.

- [x] Eric registered on the hackathon's Devpost page and accepted the rules (Eric does this himself).
      Evidence: Eric registered on Nov 16, 2026 (relayed from Eric's review chat, Nov 21).
- [x] Repo public on GitHub, Apache-2.0 LICENSE showing in the About box.
      Evidence: https://github.com/95rjn65ncd-blip/smell-test created public Nov 20 (Eric's OK), Actions disabled;
      logged-out page and raw README return 200; GitHub API reports license apache-2.0.
- [x] README: value proposition, setup, links to the exact files and lines for `HybridModel`, `generativeModelSession`,
      `respond` / `streamResponse`, the benchmark, the privacy design, "built during the submission period".
      Evidence: README "How hybrid inference is used" links CheckEngine.swift#L61-L63, #L68, #L126-L135 and
      SmellTestApp.swift#L19-L21 (Nov 18). The app uses `respond` only, not `streamResponse`.
- [x] No API keys, debug tokens, `GoogleService-Info.plist` or personal data committed. Full git history scanned before going public.
      Nov 18 scan of all history: 0 `GoogleService-Info.plist`, 0 API-key / private-key / token patterns, 0 debug
      tokens. Open: Eric's contact email is in site/ and docs/APP_STORE.md (approved for the pages; confirm for a
      public repo), and every commit's author email is Eric's Apple private-relay address. Rescan right before going public.
      Nov 20 rescan, all 46 commits: 0 `GoogleService-Info.plist`, 0 key/token patterns, 0 debug tokens, no files
      over 1 MB, no local paths; phone numbers are all fictional 555 numbers; other emails are made-up test data.
      Only real contact: smokylive@icloud.com (Eric to confirm it's OK public).
- [ ] Billing switched to paid by Nov 25: $10/$25 budget alerts, daily Gemini cap (start 2,000/day), rate limits on the public demo.
- [ ] Early TestFlight build sent to external Beta App Review (~Nov 20).
- [ ] TestFlight public link works, App Attest, free, available through Dec 16.
- [x] Hosted Chrome web app link works: https://iossmelltest.web.app/check (deployed Nov 19; on-device check and cloud second opinion verified live with App Check).
- [ ] YouTube video ≤ 3:00, public, English. A cut without the image check exists as backup.
- [ ] Description: how Firebase AI Logic is used, features, value, what was built in the period, pre-existing work disclosed.
- [ ] Platforms selected: iOS, plus Web/Chrome if it ships.
- [x] Screenshots. Evidence: docs/screenshots/1-5, 1320×2868, Release build, made-up messages (Nov 17).
- [ ] App Store release is NOT required for the contest. App Review sent 1.0 back (2.1 information request);
      parked until after the contest. Fix the blockers in docs/COMPLIANCE.md before resubmitting.
- [ ] Submitted by Nov 29. Every link checked from a logged-out browser.
