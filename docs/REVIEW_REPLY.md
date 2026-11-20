# App Review: Guideline 2.1 "Information Needed" (Nov 20, 2026)

Apple rejected 1.0 (5) on Nov 20, 3:56 PM, under 2.1.0 App Completeness. It is a request for information, not a
bug report. Apple asks for 6 things in the App Review Information **Notes** field, then a resubmit.

What's needed:
1. **Screen recording on a physical iPhone, latest iOS, starting from launching the app.** Eric records it (see shot list
   below). No account, user content or paid features exist, so none of those flows apply.
2–6. The Notes text below (draft; Eric approves before it's entered). Under 4,000 characters.

## Recording shot list (about 60–90 seconds, iPhone Screen Recording from Control Center)

1. Start recording on the Home Screen, tap Smell Test to launch it.
2. Tap the sample "Package fee text", tap Check it, scroll through the answer.
3. Tap Check another message, tap the sample "Hi Mum, new number", tap Check it.
4. Tap Get a second opinion, show the "Before it's sent" preview, tap Send, show the second opinion.
5. Open Safari or Notes, select some text, Share → Smell Test, show the on-device answer.
6. Stop recording. Attach it on the 1.0 page, App Review Information → Attachment.

## Notes draft

> 1. Screen recording: attached. It starts at launch on a physical iPhone running the latest iOS and shows the full
> flow. The app has no accounts, no sign-in, no user-generated content shared with others, and no paid content.
>
> 2. Purpose and audience: Smell Test helps anyone, especially people who are less confident online, spot scam
> texts, emails and links before they tap, reply or pay. The user pastes or shares a message and gets a plain
> answer (Scam, Likely scam, Not sure, or No red flags found), the exact words that raised concern, and simple
> next steps. Its value is privacy: the first check runs entirely on the iPhone with Apple Intelligence, so private
> messages don't have to be pasted into an online chatbot.
>
> 3. How to use it: no login is needed. Open the app and tap one of the "Try a sample" messages (all made up), then
> tap Check it. To see the optional cloud second opinion, use the "Hi Mum, new number" sample and tap Get a second
> opinion: the app removes personal details on the device, shows exactly what will be sent, and sends only after
> the user taps Send. Text can also be shared from other apps with the share sheet (checked on-device only), and a
> screenshot can be checked (text is read on-device). The on-device check needs an iPhone with Apple Intelligence
> turned on; without it, the app says so and sends nothing unless the user asks for a second opinion.
>
> 4. External services: Apple Foundation Models (on-device, no network). Google Firebase AI Logic with the Gemini
> API, used only for the optional second opinion and only with text the user approved after personal details were
> removed. Firebase App Check (App Attest) to protect that request, and Firebase Remote Config for settings (the
> cloud model name, an on/off switch and current scam patterns). No analytics, ads, payments or account services.
>
> 5. Regions: the app works the same in every region where it's offered. The on-device check depends on Apple
> Intelligence being available for the device, region and language; the interface is in English.
>
> 6. Regulated industry or third-party material: not applicable. The app gives general guidance only, not financial
> or legal advice. All sample messages, people and companies are made up.
