# Mobile Client (Flutter) - Cheat-Proof Indoor Attendance

The mobile client enforces a strict **Defense-in-Depth** multi-factor presence gauntlet before an attendance request can be cryptographically signed and dispatched to the university's intranet backend.

---

## 🔒 Verification Architecture

When a student marks attendance, the application executes a 6-stage gauntlet:

1. **GPS & Mock Location Check:**
   - Obtains fine GPS satellite fix.
   - Evaluates `position.isMocked == false` (flags mock location providers).
   - Verifies geodesic distance to campus center ($\le 150\text{m}$).
2. **Classroom Wi-Fi BSSID Check:**
   - Reads the hardware MAC address of the connected Wi-Fi router.
   - Compares against allowed classroom AP BSSIDs.
3. **ESP32 BLE Beacon Proximity Check:**
   - Scans for the classroom's ESP32 iBeacon UUID.
   - Asserts $\text{RSSI} > -70\text{ dBm}$ (confirms student is physically inside the room).
4. **Dynamic TOTP QR Ingestion:**
   - Scans the teacher's screen casting a 10-second rolling TOTP QR code.
5. **Biometric Hardware Signature:**
   - Prompts for Biometric (Fingerprint/Face ID).
   - Authorizes the hardware Secure Enclave / Android KeyStore to sign the scanned QR payload using the device's private RSA key.
   - Private key never leaves the secure hardware chip.
   - Key is generated with `setInvalidatedByBiometricEnrollment = true` (adding any new biometric invalidates the key).
6. **Intranet Submission:**
   - Dispatches payload and RSA signature via HTTP to the local Node.js API server (`192.168.10.50:3000`).

---

## ⚙️ Configuration

All deployment-specific constants are centralized in [`lib/config/constants.dart`](lib/config/constants.dart):

```dart
// URLs
static const String localBackendUrl = 'http://192.168.10.50:3000';
static const String supabaseLocalUrl = 'http://192.168.10.50:8000';
static const String supabaseAnonKey = 'YOUR_SELF_HOSTED_SUPABASE_ANON_KEY';

// Campus Geofence
static const double campusLat = 15.3920;
static const double campusLng = 75.0255;
static const double maxCampusRadiusMeters = 150.0;

// Classroom Hardware
static const String targetBeaconUUID = 'B9407F30-F5F8-466E-AFF9-25556B57FE6D';
static const int minBeaconRssi = -70;
static const List<String> validClassroomBSSIDs = [
  '00:14:22:01:23:45',
  '00:14:22:01:23:46',
];
```

---

## 🛠️ Build & Development

### Prerequisites
- Flutter SDK $\ge 3.24.0$
- Android Studio / Xcode
- Physical device with Biometric sensor and BLE support (emulators cannot test Secure Enclave or BLE ranging)

### Setup
```bash
cd mobile
flutter pub get
```

### Run in Debug Mode
```bash
flutter run
```

### Production Release (Security Hardened & Obfuscated)
To prevent reverse-engineering of validation endpoints and cryptographic verification routines:

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=./build/debug-info
```

For iOS:
```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=./build/debug-info
```
