# ZEGOCLOUD Call Project — Setup Guide

## Architecture

```
Web User (home_app)              Firebase Firestore             Executive (executive_app)
      |                               |                                  |
 Click "Call"  ──── writes calls/{id} {status:"ringing"} ────► listener wakes
      |                               |                                  |
 Waits for                           |                        IncomingCallScreen shown
 status change                       |                                  |
      |                    ◄─ status:"accepted" ────────────── Accept pressed
      |                               |                                  |
 joinRoom()                          |                           joinRoom()
      └──────────── ZEGOCLOUD room (roomId) ──────────────────────────┘
                         Voice call established
```

## Project Structure

```
zego_call_project/
├── home_app/             Flutter Web — web user initiates call
│   └── lib/
│       ├── main.dart
│       ├── constants.dart
│       ├── models/call_model.dart
│       ├── screens/
│       │   ├── home_screen.dart      call button
│       │   └── call_screen.dart      active call UI
│       └── services/
│           ├── zego_service.dart     ZEGOCLOUD engine wrapper
│           └── signaling_service.dart Firestore signaling
├── executive_app/        Flutter Android — executive receives call
│   └── lib/
│       ├── main.dart
│       ├── constants.dart
│       ├── models/call_model.dart
│       ├── screens/
│       │   ├── home_screen.dart          waiting screen
│       │   ├── incoming_call_screen.dart accept/reject
│       │   └── call_screen.dart          active call UI
│       └── services/
│           ├── zego_service.dart
│           └── signaling_service.dart
└── firestore.rules       deploy to Firebase
```

---

## Step 1 — ZEGOCLOUD Credentials

1. Sign up at https://console.zegocloud.com
2. Create a project → copy **AppID** (int) and **AppSign** (64-char hex)
3. Replace in **both** `lib/constants.dart` files:

```dart
static const int appId = 123456789;       // your AppID
static const String appSign = 'abcdef...'; // your AppSign
```

> For production, generate Tokens server-side. For prototyping, AppSign mode is fine.

---

## Step 2 — Firebase Project

1. Go to https://console.firebase.google.com → New project
2. Enable **Firestore** (test mode)
3. Add a **Web app** → copy config into `home_app/lib/constants.dart`:

```dart
class FirebaseConfig {
  static const String apiKey           = 'AIza...';
  static const String authDomain       = 'your-project.firebaseapp.com';
  static const String projectId        = 'your-project';
  static const String storageBucket    = 'your-project.appspot.com';
  static const String messagingSenderId = '123456789';
  static const String appId            = '1:123:web:abc';
}
```

4. Add an **Android app** (package: `com.example.executive_app`)
   - Download `google-services.json` → place in `executive_app/android/app/`

5. Deploy Firestore rules:
```bash
firebase deploy --only firestore:rules
```

---

## Step 3 — Run home_app (Web)

```bash
cd home_app
flutter run -d chrome
```

---

## Step 4 — Run executive_app (Android)

```bash
cd executive_app
flutter run -d <your-device-id>
```

---

## Call Flow

1. Web user opens home_app → taps **Start Call**
2. Firestore `calls/{id}` created with `status: "ringing"`
3. Executive app Firestore listener triggers → **IncomingCallScreen** appears
4. Executive taps **Accept** → Firestore status → `"accepted"`, joins ZEGOCLOUD room
5. Web app sees `"accepted"` → joins same ZEGOCLOUD room
6. Voice call begins (both publish their audio stream, play each other's)
7. Either side taps **End Call** → Firestore status → `"ended"` → both leave room

---

## Notes

- **Background calls on Android**: The app uses a Firestore real-time listener.
  When the app is killed, FCM delivers the notification. Tap it to open the app —
  the Firestore listener then shows IncomingCallScreen.
- **Web permissions**: Chrome will prompt for microphone on first call.
- **Tokens in production**: Replace AppSign mode with server-generated tokens.
