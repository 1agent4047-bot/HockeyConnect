# HockeyConnect — Setup Guide

## 1. Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create project → name it `hockeyconnect-phoenix`
3. **Authentication** → Sign-in method → enable:
   - Apple (requires Apple Developer account)
   - Google
   - Email/Password
   - Phone
4. **Firestore** → Create database → Start in **production mode**
5. **Cloud Messaging** → Already enabled by default

### Firestore Security Rules (paste in Rules tab)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /players/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /groups/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /games/{gameId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    match /payments/{paymentId} {
      allow read: if request.auth.uid == resource.data.payerId;
      allow write: if false; // only Cloud Functions write payments
    }
  }
}
```

6. **Download** `GoogleService-Info.plist` (Project Settings → iOS app → bundle ID: `com.hockeyconnect.app`)
7. Replace `HockeyConnect/GoogleService-Info.plist` with the downloaded file

---

## 2. Stripe Account

1. Sign up at [stripe.com](https://stripe.com)
2. Get your **Secret Key** (Dashboard → Developers → API keys)
3. Set up a webhook endpoint pointing to your Cloud Function URL for `payment_intent.succeeded`
4. Get your **Webhook Signing Secret**

---

## 3. Apple Developer Setup

1. **Apple Pay merchant ID**: In your Apple Developer account → Identifiers → Merchant IDs → create `merchant.com.hockeyconnect.app`
2. **Push Notifications**: In your app's ID, enable Push Notifications capability, upload APNs certificate to Firebase
3. **Sign in with Apple**: Enable in your app's ID

---

## 4. Deploy Cloud Functions

```bash
cd functions
npm install
firebase login
firebase use --add  # select your project

# Set Stripe secrets
firebase functions:config:set stripe.secret="sk_live_..." stripe.webhook_secret="whsec_..."

firebase deploy --only functions
```

Copy the deployed function URL and update `PaymentService.swift`:
```swift
private let createIntentURL = URL(string: "https://us-central1-YOUR_PROJECT.cloudfunctions.net/createPaymentIntent")!
```

---

## 5. Open in Xcode

```bash
open HockeyConnect.xcodeproj
```

- Select your team in **Signing & Capabilities**
- Build on a real device for Apple Pay testing (not available in simulator)
- SPM packages will resolve automatically on first build (takes ~2 min)

---

## 6. TestFlight

1. Archive → Product → Archive
2. Distribute via TestFlight
3. Invite your Phoenix hockey groups as testers first
