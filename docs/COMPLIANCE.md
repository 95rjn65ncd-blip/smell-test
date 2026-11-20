# Compliance check before resubmitting (Nov 20, 2026)

Nothing gets resubmitted until every **Blocker** is fixed and ticked with evidence.

Sources read today (live):
- App Review Guidelines, last updated Oct 16, 2026: https://developer.apple.com/app-store/review/guidelines/
- Gemini API Additional Terms, effective Mar 23, 2026: https://ai.google.dev/gemini-api/terms (now aistudio.google.com/docs/terms)
- Gemini API available regions: https://ai.google.dev/gemini-api/docs/available-regions
- Firebase AI Logic data governance: https://firebase.google.com/docs/ai-logic/data-governance

## Why Apple sent it back

Guideline 2.1, Information Needed. Apple wants a screen recording made on a real iPhone, plus answers to 5 questions
in the Notes. Draft: `docs/REVIEW_REPLY.md`. It must be updated after the fixes below (regions, age, billing).

## Blockers (must fix before resubmitting)

| # | Problem | Rule | Fix | Who |
|---|---|---|---|---|
| B1 | The app is rated 4+, but Google's Gemini terms say you must be 18+ and the API must not be used in an app "likely to be accessed by individuals under the age of 18". | Gemini API terms; Apple 5.2.2 (third-party service terms) | Set the App Store age rating to 18+ (the override for a higher rating in the Age Rating section), and say "for adults 18+" in the privacy policy. Or remove the cloud second opinion from the iPhone app. | Eric decides; ASC change needs his OK |
| B2 | Gemini runs on Google's free tier. The terms allow only paid services for users in the EEA, Switzerland and the UK, and say not to send personal information to the free tier. On the free tier Google also uses the text to improve its products and human reviewers may read it. | Gemini API terms; Apple 5.1.2(i) | Link a billing account to the Firebase project (Blaze) before the app is released, with budget alerts and a cap. Then update the privacy policy paragraph. | Eric (billing) |
| B3 | The app is offered in Russia, Belarus, Hong Kong, Macau and Myanmar, where the Gemini API isn't available. Google's terms allow making the app available only in available regions. | Gemini API terms | Remove those 5 storefronts in Pricing and Availability (China is already excluded). | ASC change needs Eric's OK |
| B4 | There's no link to the privacy policy inside the app. Apple requires one "within the app" as well as in App Store Connect. | Apple 5.1.1(i) | Add a privacy policy link in the app (new build 6). | Code; the label needs Eric's OK |
| B5 | The screen before sending says the text will "go to the cloud" but doesn't say who receives it. Apple requires a clear disclosure when data is shared "with third-party AI", plus explicit permission. The Send tap is the permission; the disclosure is missing. | Apple 5.1.2(i) | Name Google's Gemini on that screen (new build 6). | Code; the wording needs Eric's OK |
| B6 | The description says "Smell Test is open source", but the repo is private. Apple requires accurate metadata. | Apple 2.3.1 / 2.3.7 | Make the repo public before release (after the history rescan), or remove the sentence. | Eric decides |

## Should fix (low risk, but do them)

- **Privacy policy (5.1.1(i)).**
  - Say how long data is kept: Cognito Agora keeps nothing; Google keeps it under its terms (paid tier: logged for a limited time to detect abuse).
  - Say how to withdraw consent: each second opinion is a one-time choice; don't tap Send.
  - Say Google is held to equal protection under its terms.
  - Replace "not directed at children under 13" with 18+ if B1 goes that way.
- **Description (2.5.1, 5.1.2(i)).** Say the second opinion uses Google's Gemini through Firebase.
- **Review Notes.** Update item 5 (regions) and item 2 (audience 18+) once B1 and B3 are decided.

## Checked and OK

- **No accounts or sign-in (5.1.1(v)).** Account deletion doesn't apply.
- **Screenshots use the system photo picker (5.1.1(iii)).** The app sees only the picture the user picks, and needs no photo permission.
- **Share extension (4.4).** No ads or marketing.
- **Debug-only buttons and diagnostics are excluded from release builds.** They're inside `#if DEBUG` (2.5.19 hidden features).
- **Remote Config delivers values only, not code (2.5.2).** Values: model name, on/off switch, threshold, patterns.
- **App Attest is set to production.**
- **Support page (1.5).** It has a contact email.
- **Privacy policy URL** is live and covers the on-device check, screenshots, the second opinion, App Check and Remote Config.
- **No "safe" verdict.** The description says the app can be wrong. There are no malware-scanning or guaranteed-detection claims (2.3.1).
- **Keywords contain no trademarks.** Screenshots and sample messages use made-up people and companies (2.3.7, 2.3.9, 5.2.1).
- **The App Privacy label** lists Other User Content, not linked to the user and not used for tracking. It matches the app.
- **Spam and scam criteria are described in the listing ("What it looks for") (2.5.12).**
- **Not triggered:** in-app purchases, payments, user content shared with others, chatbot rules, kids category, medical rules.
