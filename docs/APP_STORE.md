# App Store Connect listing (DRAFT — needs Eric's OK before anything is entered)

**Parked until after Nov 30 (Eric, Nov 16):** App Information, the Version page, App Review Information and
Age rating below are for a public App Store launch, not the contest. Only these are in scope now:
privacy policy and support pages, TestFlight Test Information, App Privacy, and screenshots.

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

**Version:** the store shows 1.0, but the build is 0.1.0. Before App Store submission, set
`MARKETING_VERSION` to 1.0 (TestFlight doesn't care).

## App Review Information

- Sign-in required: **No**
- Contact: Eric Crawley (phone and email entered by Eric in App Store Connect, not stored here)
- Notes:

> No account or sign-in. To test: paste a sample message such as "ParcelPoint: your package is on hold. Pay
> the $1.99 redelivery fee at parcelpoint-redelivery.top" and tap Check it. The first check runs on-device
> with Apple Intelligence (needs an Apple Intelligence iPhone with it turned on). "Get a second opinion"
> removes personal details, shows a preview, and only sends after the user approves. The share sheet
> extension checks shared text on-device only.

## App Privacy (must match `ios/SmellTest/PrivacyInfo.xcprivacy`)

- Data collected: **Other User Content** (the message with personal details removed, only when the user
  approves a second opinion)
  - Linked to the user: No
  - Used for tracking: No
  - Purpose: App Functionality
- Note: Firebase App Check and Remote Config also run. Their SDKs declare their own data; check the Firebase
  docs for what to declare before submitting (to verify, not assume).

## Age rating

All answers "None" / "No". Expected rating: 4+.

## TestFlight Test Information (needed for external testing only)

- Beta App Description: the first paragraph of the Description
- Feedback email: Eric's choice
- What to Test: "Paste or share messages that feel off. Try the second opinion on a Not sure answer and check
  the preview before sending."

## Screenshots (6.9" iPhone, 1320 × 2868, from the iPhone 17 Pro Max simulator)

1. Home screen with a pasted made-up delivery-fee text
2. "Likely scam" result with quotes and steps
3. "Not sure" with the second-opinion button
4. Privacy Shield preview (personal details removed)
5. Share sheet result

## Open decisions

1. ~~Privacy policy and support pages.~~ Done Nov 17: Firebase Hosting (URLs above).
2. **Gemini data use.** On the free Gemini Developer API tier, Google may use prompts to improve its
   products. Until billing is switched to paid (planned by Nov 25), the privacy policy must say so. Don't
   claim cloud text isn't used for training.
