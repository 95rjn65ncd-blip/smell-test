# App Store Connect listing

**Entered Nov 20 (Eric asked for every field to be filled in):** App Information (subtitle, Utilities /
Productivity, content rights: none), age rating (all None/No, 4+), price Free, and on the iOS 1.0 page:
promotional text, description, keywords, support URL, copyright, five 6.3" screenshots (the 6.9" set
resized to 1206 × 2622), "Sign-in required" unticked, review contact and notes.
Availability (Eric, Nov 20): every country except mainland China (174 available), which would need its own
Security Assessment and AI content filings.
Review contact phone entered by Eric; the 1.0 page saved and verified after reload (Nov 20). "Add for Review" is
enabled. **Submitted for App Review by Eric on Nov 20.**

Every scam example, person and company below is made up.

## App Information

| Field | Draft |
|---|---|
| Name | Smell Test by Cognito Agora (approved Nov 16) |
| Subtitle (30) | Check a message before you act |
| Primary category | Utilities |
| Secondary category | Productivity |
| Content rights | Does not contain, show or access third-party content |
| Copyright | © 2026 Cognito Agora, Inc. |

## Version page

**Promotional Text (170)**

> Got a text that feels off? Paste it in. Smell Test checks it on your iPhone first, and asks before sending
> anything to the cloud.

**Description**

> Smell Test helps you spot scam texts, emails and links before you tap, reply or pay.
>
> Paste a message, or share it from another app, and Smell Test checks it with Apple Intelligence on your
> iPhone. You get a plain answer: Scam, Likely scam, Not sure or No red flags found. You also see the exact
> words that raised the alarm, and three simple next steps.
>
> PRIVATE BY DESIGN
> • The first check runs on your iPhone. Your message isn't sent anywhere for it.
> • Not sure? You can ask for a second opinion from a larger cloud model. Smell Test first removes names,
>   phone numbers, emails, account numbers and other personal details, shows you exactly what will be sent,
>   and sends it only if you agree.
>
> WHAT IT LOOKS FOR
> Fake delivery fees and unpaid tolls, bank and government impersonation, "Hi Mum, new number" family
> emergencies, prize and job offers, romance and crypto investment pitches, tech support scams and more.
>
> ALREADY CLICKED OR PAID?
> Turn on "Already clicked, paid or shared?" for recovery steps.
>
> Smell Test can be wrong. It never says a message is "safe". If something feels off, contact the sender
> using a number or app you already trust.
>
> Smell Test is open source.

**Keywords (100)**

> scam,spam,phishing,text,sms,fraud,checker,email,link,detector,security,privacy,smishing

**Privacy Policy URL:** https://iossmelltest.web.app/privacy
**Support URL:** https://iossmelltest.web.app/support
(Firebase Hosting, project iossmelltest, live Nov 17; source in `site/`.)

**Version:** 1.0. Build 5 (Nov 19) is version 1.0 and is attached to iOS 1.0, which is what makes the
app icon show in App Store Connect. Builds 1–4 were 0.1.0 and exported as TestFlight-internal-only, so
they can't be attached to an App Store version. Submitted for review Nov 20 (by Eric).

## App Review Information

- Sign-in required: **No**
- Contact: Eric Crawley (phone and email entered by Eric in App Store Connect, not stored here)
- Notes:

> No account or sign-in. To test: paste a sample message such as "ParcelPoint: your package is on hold. Pay
> the $1.99 redelivery fee at parcelpoint-redelivery.top" and tap Check it. The first check runs on-device
> with Apple Intelligence (needs an Apple Intelligence iPhone with it turned on). "Get a second opinion"
> removes personal details, shows a preview, and only sends after the user approves. The share sheet
> extension checks shared text on-device only.

## App Privacy (must match `ios/SmellTest/PrivacyInfo.xcprivacy`) — PUBLISHED in ASC Nov 17 (Eric's OK)

- Data collected: **Other User Content** (the message with personal details removed, only when the user
  approves a second opinion)
  - Linked to the user: No
  - Used for tracking: No
  - Purpose: App Functionality
- Data collected: **Other Diagnostic Data** (declared by the Firebase Installations and Remote Config SDK
  privacy manifests in the archived build; Remote Config also reads country, language, time zone and OS
  version per the Firebase docs, read Nov 17)
  - Linked to the user: No
  - Used for tracking: No
  - Purpose: Analytics
- Checked Nov 17: every other bundled Firebase/Google manifest declares no collected data. AI monitoring is
  off in the console, so AI Logic doesn't collect prompts.

## Age rating

All answers "None" / "No". Expected rating: 4+.

## TestFlight Test Information (needed for external testing only) — entered Nov 17

Beta description, feedback email and privacy URL saved. Beta App Review contact (name, email, notes)
needs Eric's phone number before it saves.

- Beta App Description: the first paragraph of the Description
- Feedback email: smokylive@icloud.com (approved Nov 16)
- Privacy Policy URL: https://iossmelltest.web.app/privacy
- What to Test: "Paste or share messages that feel off. Try the second opinion on a Not sure answer and check
  the preview before sending."

## Screenshots (6.9" iPhone, 1320 × 2868, from the iPhone 17 Pro Max simulator)

1. Home screen (navy style, Nov 17) with the made-up delivery-fee sample filled in
2. Result card with quotes and steps
3. "Not sure" with the second-opinion button
4. Privacy Shield preview (personal details removed)
5. Share sheet result

## Open decisions

1. ~~Privacy policy and support pages.~~ Done Nov 17: Firebase Hosting (URLs above).
2. **Gemini data use.** On the free Gemini Developer API tier, Google may use prompts to improve its
   products. Until billing is switched to paid (planned by Nov 25), the privacy policy must say so. Don't
   claim cloud text isn't used for training.
