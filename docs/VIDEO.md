# Demo video: script and shot list (DRAFT)

Target length **2:45** (limit 3:00). English. YouTube, public. Eric uploads it himself.
About 400 words of narration, so read it at an easy pace.

**Rules for the recording**
- Use only the made-up messages below (they are the app's built-in samples). No real names, numbers, companies or logos.
- Say only what's on screen. If the model gives a different answer than the script expects, narrate what it actually
  said, or record that take again. Never edit a result.
- Never say "safe". The app says "No red flags found".
- Record the iPhone app with a real device (Apple Intelligence on). Use QuickTime → New Movie Recording → choose the
  iPhone as the camera. Turn on Do Not Disturb first so no notifications show.
- Record Chrome with the window at about 1280×800. Use a Chrome profile with no bookmarks or extensions showing.

**Backup cut:** if a shot fails on the day, drop scene 5 (screenshots). The video still covers everything judges score.

---

## Scene 1: The problem (0:00–0:15)

**Shot:** iPhone home screen, then a text message preview: the "Package fee text" sample.

**Say:** "Scam texts work because they rush you. Pay a fee in twelve hours. Your bank account locks today. And
most people won't paste a private message into a chatbot, which is fair. This is Smell Test."

## Scene 2: First check, on the iPhone (0:15–0:45)

**Shot:** Open Smell Test. Tap the sample **Package fee text**, then **Check it**. Show "Checking on your iPhone…",
then the verdict. Scroll slowly through **Why** (the quoted words), the three steps, and
**Already clicked, paid or shared?**

**Say:** "Paste or share any message. The first check runs entirely on the iPhone, using Apple's on-device model
through Firebase AI Logic. In about two seconds it gives a plain answer, shows the exact words that raised the
alarm, and tells you what to do next, including what to do if you already paid."

## Scene 3: Proof it stays on the phone (0:45–1:00)

**Shot:** Swipe down Control Center, turn on Airplane Mode. Check the **Bank sign-in alert** sample. On the result,
hold on "What left your iPhone: nothing", then tap the green **Checked on your iPhone** badge to open
**Where this ran**. Turn Airplane Mode off.

**Say:** "That works in airplane mode, because nothing left the phone. The app shows you that, every time."

## Scene 4: The hard case and the Privacy Shield (1:00–1:45)

**Shot:** Check the **"Hi Mum, new number"** sample. Show the verdict and the **Get a second opinion** button.
Tap it. On **Before it's sent**, hold on the redacted text: the name is removed, "Mum" stays. Tap **Send**. Show
"Getting a second opinion…", then the cloud verdict and the line "Your iPhone said … The second opinion says …".
Scroll to "What left your iPhone (exactly):" and hold on it. The badge now says **Checked in the cloud**.

**Say:** "Some scams have no link and no money in the first message, like 'Hi Mum, new number'. A small model
can miss that. So Smell Test never trusts the model's confidence. It offers a second opinion when the model isn't
sure, or when fixed warning-sign checks disagree with it, like here: a family member, a new number, and a move to
another app.

"Before anything goes to the cloud, the Privacy Shield removes names, numbers, emails and links on the phone, and
shows you exactly what will be sent. You can edit it. Nothing leaves until you tap Send. Then Gemini, through
Firebase AI Logic, gives the second opinion, and the app shows exactly what left."

> If the iPhone answers "Not sure" instead of "No red flags found", change the second sentence of the narration to
> "Here the iPhone isn't sure, so it offers one."

## Scene 5: Screenshots and read-aloud (1:45–2:00) — cut first if short on time

**Shot:** Tap **Choose screenshot**, pick a screenshot of the Package fee text. Show "Reading your screenshot on your
iPhone…" and the verdict. Tap **Read aloud** for a second, then **Stop**.

**Say:** "You can check a screenshot too. The words are read on the phone. And it can read the answer aloud."

## Scene 6: The same rules in Chrome (2:00–2:25)

**Shot:** Chrome at https://iossmelltest.web.app/check. Paste the **Bank sign-in alert** message, check it, show the
verdict and the on-device badge. Then paste the **Hi Mum** message, show the "second opinion" prompt and the
preview of what will be sent.

**Say:** "There's a Chrome version too. The first check runs on Chrome's built-in model, on your computer. It uses
the same rules as the iPhone app, and tests check the two give the same answers."

## Scene 7: How it's built, and the numbers (2:25–2:45)

**Shot:** A simple title card (plain text, no logos), or the README's benchmark table scrolled into view:

| On-device first pass (holdout) | |
|---|---|
| Scams missed | 1% |
| Ordinary messages wrongly flagged | 6% |
| Second opinion offered | 30% |
| Median time | 2.5 s |

End card: **Smell Test by Cognito Agora** · open source, Apache-2.0 · github link · iossmelltest.web.app/check

**Say:** "Raw text stays on the device. The cloud is used only for the hard cases, only with your approval. App
Check protects every call, and Remote Config lets us update scam patterns without a new release. On 150 made-up
test messages, it missed one percent of scams. Smell Test, by Cognito Agora."

---

## Before uploading

- [ ] Watch it once with the sound off: every claim must be visible on screen.
- [ ] No notifications, real names, phone numbers, emails or accounts visible in any frame.
- [ ] Length 3:00 or less.
- [ ] Repo link in the end card works from a logged-out browser (the repo must be public first).
- [ ] Numbers match the newest file in `benchmark/results/`.
