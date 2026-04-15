<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41.6-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/Hardware-ESP8266-E7352C?style=for-the-badge"/>
</div>

<br/>

<div align="center">
  <h1>🌿 EcoSynth</h1>
  <p><strong>Real-time IoT Control Dashboard for ESP8266 Smart Irrigation Systems</strong></p>
  <p>Monitor battery telemetry and control actuators with a hardware safety interlock — all from your phone.</p>
</div>

---

## 📱 Screenshots

> Connect your ESP8266 with data streaming to see live telemetry and controls.

| Dark Mode | Light Mode |
|:---------:|:----------:|
| _Coming soon_ | _Coming soon_ |

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🟢 **ESP Live Indicator** | Dot turns green **only** when ESP8266 is actively pushing telemetry. Turns red/orange otherwise. |
| ⚡ **Real-time Telemetry** | Live battery % and voltage readings from Firebase with animated cards. |
| 🔌 **Hardware Controls** | Toggle Charger, Water Pump, and Mist Maker directly from the app. |
| 🔒 **Safety Interlock** | App enforces a strict mutual-exclusion rule between charging and actuation — protecting your TP4056 and 18650 cell. |
| 🌙 **Dark / Light Mode** | Toggle with one tap. Preference is saved between sessions. |
| 🎨 **Animated Splash** | Elastic logo entry, slide-up text, and fade transition to dashboard. |
| 📴 **Offline State** | Clear contextual banners for Firebase offline vs. ESP offline — never silently fails. |

---

## 🔧 Hardware Setup

### Components
| Component | Role |
|-----------|------|
| **ESP8266** | Microcontroller — reads sensors and writes to Firebase |
| **18650 Li-Ion Cell** | Power source for actuators |
| **TP4056 Module** | Charging IC — controlled via relay |
| **5V Water Pump** | Actuator — MOSFET-switched |
| **5V Mist Maker** | Actuator — Relay-switched |

### Split-Rail Power Architecture
```
Mains Power  ──►  ESP8266 Logic (3.3V LDO)
                  └── Relay Output ──► TP4056 EN pin

18650 Battery ──► Water Pump (MOSFET Gate from ESP GPIO)
               └► Mist Maker (Relay from ESP GPIO)
```

> ⚠️ **Critical Rule**: Never charge and actuate simultaneously. The app enforces this in software, but also implement a hardware interlock if possible.

---

## 🔥 Firebase Setup

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use an existing one)
3. Enable **Realtime Database** (choose nearest region)

### 2. Database Structure
Set up the following nodes in your Realtime Database:

```
/
├── telemetry/
│   ├── percentage    (Integer: 0–100)  — ESP writes battery %
│   └── voltage       (Float: 3.20–4.20) — ESP writes raw voltage
└── control/
    ├── charger_relay (Boolean) — App reads/writes
    ├── pump          (Boolean) — App reads/writes
    └── mist          (Boolean) — App reads/writes
```

### 3. Database Rules (Development / Local Testing)
> ⚠️ Use open rules only for local hardware testing. Add authentication before any public deployment.

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

### 4. Get Your Credentials
1. Firebase Console → Project Settings → Your Apps
2. Add a **Web App** (or copy from existing)
3. Copy the config values

---

## 🚀 Flutter App Setup

### Prerequisites
- Flutter SDK ≥ 3.41.6 ([Install Guide](https://docs.flutter.dev/get-started/install))
- Android device with USB Debugging enabled
- Firebase project configured (see above)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Pratik4875/EcoSynth.git
cd EcoSynth

# 2. Install dependencies
flutter pub get

# 3. Add your Firebase credentials
#    Open lib/main.dart and fill in the config block at the top:
```

```dart
// lib/main.dart — Firebase Configuration Block
const _firebaseOptions = FirebaseOptions(
  apiKey:            'YOUR_API_KEY',
  appId:             'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId:         'YOUR_PROJECT_ID',
  databaseURL:       'https://YOUR_PROJECT_ID-default-rtdb.REGION.firebasedatabase.app',
);
```

```bash
# 4. Run on your Android device
flutter devices        # confirm device is listed
flutter run            # deploy and launch
```

### Building the Release APK

```bash
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry, Firebase init, theme notifier
├── theme/
│   └── app_theme.dart           # Dark & Light ThemeData definitions
├── widgets/
│   └── sg_logo.dart             # Custom leaf+circuit logo (CustomPainter)
└── screens/
    ├── splash_screen.dart       # Animated splash with elastic logo + loading dots
    └── dashboard_screen.dart    # Full dashboard UI + Firebase logic
```

---

## 🔒 Safety Interlock Logic

The interlock is implemented in `_toggle()` inside `dashboard_screen.dart`:

```
[User toggles Pump ON]
    → Is Charger currently ON?
        YES → Write charger_relay = false to Firebase FIRST
             → Then write pump = true
        NO  → Write pump = true directly

[User toggles Charger ON]
    → Is Pump currently ON?  → Write pump = false first
    → Is Mist currently ON?  → Write mist = false first
    → Write charger_relay = true
```

Any Firebase write failure triggers an automatic **rollback** to the previous state and shows a snackbar error.

---

## 📡 ESP Connectivity Detection

The app uses a **two-layer detection system** instead of relying solely on Firebase connectivity:

| Signal | Source | What it means |
|--------|--------|---------------|
| `_firebaseConnected` | `.info/connected` node | Phone has a live socket to Firebase servers |
| `_espLive` | Watchdog timer | ESP sent telemetry within the last **30 seconds** |

The **status dot** and **AppBar label** go green only when **both** signals are true.

> 💡 If your ESP pushes data every N seconds, set `_espTimeoutSeconds > N` in `dashboard_screen.dart`.

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.13.0 | Firebase initialization |
| `firebase_database` | ^11.3.5 | Realtime Database streams |
| `shared_preferences` | ^2.3.0 | Persist dark/light mode preference |

---

## 📝 License

MIT License — feel free to use, modify, and distribute.

---

<div align="center">
  <p>Built with ❤️ for rapid hardware prototyping.</p>
  <p><strong>EcoSynth</strong> — Because your garden deserves smart care.</p>
</div>
