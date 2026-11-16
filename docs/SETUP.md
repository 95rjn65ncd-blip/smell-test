# Setup

You need: a Mac with Xcode 27.2+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and a free Firebase project.
For on-device inference: an Apple Intelligence iPhone (iOS 26+) with Apple Intelligence turned on, or the
iOS Simulator on a Mac that has Apple Intelligence turned on.

## 1. Firebase project

1. In the [Firebase console](https://console.firebase.google.com), create a project.
2. **Add an iOS app** with bundle ID `com.cognitoagora.smelltest` (or your own, and change `ios/project.yml` to match).
3. Download **GoogleService-Info.plist** and put it in `ios/SmellTest/`. It is gitignored. Never commit it.
   `ios/SmellTest/GoogleService-Info.template.plist` shows the expected shape.
4. **AI Logic**: open *AI Logic* in the console, click *Get started*, and choose the **Gemini Developer API**,
   and finish every step (*Enable API*, then *Continue*). If requests fail with "genai config not found", this
   setup didn't finish: the AI Logic page still shows *Get started*.
5. **App Check**: open *Security → App Check*, register the iOS app with **App Attest**, and turn on
   enforcement for *Firebase AI Logic*.

## 2. Build and run

```bash
cd ios
xcodegen
open SmellTest.xcodeproj
```

Run the `SmellTest` scheme on a simulator or device.

## 3. App Check debug token (development builds only)

Debug builds use the App Check debug provider. On first launch the Xcode console prints a line starting with
`App Check debug token:`. Copy that value into *Security → App Check → Apps → (your iOS app) → Manage debug tokens*.
Treat it like a password: don't commit it, log it elsewhere, or paste it into chat or issues.

Release and TestFlight builds use **App Attest** instead.

## Why Firebase SDK 12.19.3 is pinned

Firebase AI Logic's `HybridModel` (on-device Apple Foundation Models first, Gemini in the cloud second) shipped in
SDK 12.13.0 and was removed in 13.0.0 in favor of `GeminiLanguageModel`, which requires iOS 27. Smell Test pins
12.19.3, the last release with `HybridModel`, so it runs on iOS 26 and 27.
