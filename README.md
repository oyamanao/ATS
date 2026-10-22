# Cheat-Proof Indoor Attendance System (ATS)

[![Backend CI](https://github.com/oyamanao/ats/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/iiitdwd/ats/actions/workflows/backend-ci.yml)
[![Flutter CI](https://github.com/oyamanao/ats/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/iiitdwd/ats/actions/workflows/flutter-ci.yml)
![Node Version](https://img.shields.io/badge/Node.js-20%2B-green.svg)
![Flutter Version](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

A multi-factor, cryptographic, and hardware-enforced indoor presence verification and attendance tracking system designed for university campuses.

Traditional attendance systems rely on single-factor checks (static QR codes, simple GPS geofences, or Bluetooth beacons) that are vulnerable to proxying, WhatsApp photo forwarding, mock location spoofing, and remote check-ins. ATS implements a multi-tier **Defense-in-Depth** architecture that combines physical room presence, cryptographic identity binding, rolling TOTP tokens, and university-locked OAuth on a self-hosted local backend.

---

## 🏛️ System Architecture

```
                     ┌─────────────────────────────────────────────────────────┐
                     │                  University Classroom                   │
                     │  ┌─────────────────────────┐  ┌──────────────────────┐  │
                     │  │ Teacher Projector Screen│  │ ESP32 iBeacon Unit   │  │
                     │  │ (Dynamic QR TOTP 10s)   │  │ (-12dBm BLE TX Power)│  │
                     │  └────────────┬────────────┘  └──────────┬───────────┘  │
                     └───────────────┼──────────────────────────┼──────────────┘
                                     │ Optical Scan             │ BLE Radio Signal
                                     ▼                          ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              Student Mobile Device                                     │
│  ┌───────────────────────┐  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │ 1. GPS + Mock Check   │  │ 2. Router BSSID Match   │  │ 3. BLE RSSI > -70 dBm    │  │
│  │ (Geofence ≤ 150m)     │  │ (Hardware AP Pinning)   │  │ (Physical Room Presence) │  │
│  └───────────┬───────────┘  └────────────┬────────────┘  └────────────┬─────────────┘  │
│              │                           │                            │                │
│  ┌───────────▼───────────────────────────▼────────────────────────────▼─────────────┐  │
│  │ 4. Hardware Key Signature (Biometric Fingerprint + Secure Enclave / KeyStore)    │  │
│  └───────────────────────────────────────┬──────────────────────────────────────────┘  │
└──────────────────────────────────────────┼─────────────────────────────────────────────┘
                                           │ Encrypted JSON over Local Wi-Fi (Intranet)
                                           ▼
                     ┌─────────────────────────────────────────────────────────┐
                     │              University Intranet Server                 │
                     │  ┌─────────────────────────┐  ┌──────────────────────┐  │
                     │  │ Node.js Intranet API    │  │ Self-Hosted Supabase │  │
                     │  │ (TOTP + RSA Signature)  │  │ (PostgreSQL + Auth)  │  │
                     │  └─────────────────────────┘  └──────────────────────┘  │
                     └─────────────────────────────────────────────────────────┘
```

---

## 🛡️ The 6-Layer Defense-in-Depth Gauntlet

| Barrier | Technology | Network Dependency | Anti-Cheat Objective |
|---|---|---|---|
| **1. Google Workspace Auth** | OAuth 2.0 PKCE | **Public Internet** | Authenticates user under `@iiitdwd.ac.in` domain. |
| **2. GPS Geofence & Mock Check** | Geolocator Hardware Fix | **Device Hardware** | Detects simulated coordinates and verifies campus presence ($\le 150\text{m}$). |
| **3. Router BSSID Pinning** | `network_info_plus` | **Local Network** | Matches physical MAC address of classroom wireless access point. |
| **4. ESP32 iBeacon Proximity** | Bluetooth Low Energy | **No Network (Radio)** | In-room RF signal check ($\text{RSSI} > -70\text{ dBm}$); wall attenuation prevents corridor marking. |
| **5. Dynamic QR Rolling TOTP** | Optical Camera Scan | **Visual Only** | Ingests rolling 10s HMAC-SHA256 token; prevents photo forwarding or static reuse. |
| **6. Hardware Key Biometric Sign** | Secure Enclave / KeyStore | **Device Silicon** | Asymmetric RSA private key signs token under biometric gate; key is non-exportable and invalidated on new biometric enrollment. |

---

## 📂 Repository Layout

```
ATS/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml             # Node.js ESLint + Jest test automation
│       └── flutter-ci.yml             # Flutter format, analyze & build APK
│
├── backend/                           # Node.js Intranet REST API & Teacher Projector
│   ├── server.js                      # Express application entrypoint
│   ├── package.json
│   ├── src/
│   │   ├── config/supabase.js         # Supabase client connector
│   │   ├── middleware/                # JWT verification & rate limiting
│   │   ├── routes/                    # Attendance submission & teacher display
│   │   ├── services/                  # TOTP validation & RSA signature verification
│   │   └── utils/logger.js            # Winston structured logger
│   └── tests/                         # Jest test suites (100% route/service coverage)
│
├── mobile/                            # Flutter Client (Android & iOS)
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── config/constants.dart      # Campus coordinates, BSSID allowlist, beacon UUID
│   │   ├── models/                    # Data transfer models
│   │   ├── services/                  # GPS, Wi-Fi, BLE, Biometric & Attendance orchestrator
│   │   ├── screens/                   # Login, Home, Registration & QR Scanner
│   │   └── widgets/                   # Status card, multi-step progress indicator, buttons
│   ├── android/                       # AndroidManifest with permissions & network security
│   └── ios/                           # Info.plist with CoreLocation, BLE & Face ID keys
│
├── firmware/                          # ESP32 Microcontroller Firmware
│   └── classroom_beacon/
│       ├── classroom_beacon.ino       # NimBLE iBeacon transmitter (-12 dBm tuned)
│       └── README.md                  # Arduino IDE flashing & wiring instructions
│
├── infra/                             # Deployment Infrastructure & Database
│   ├── docker-compose.override.yml    # Supabase Google OAuth configuration
│   └── database/
│       ├── schema.sql                 # PostgreSQL DDL, RLS policies & token cleanup trigger
│       └── migrations/                # Versioned SQL migrations
│
└── docs/                              # Technical Documentation
    ├── architecture.md                # Detailed HLD, LLD & sequence diagrams
    ├── setup-guide.md                 # Complete campus deployment guide
    ├── security-hardening.md          # Threat mitigation & obfuscation policy
    └── esp32-calibration.md           # Radio signal calibration sheet
```

---

## ⚡ Quick Start

### 1. Database & Infrastructure
```bash
# Clone Supabase Docker and apply our OAuth override
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp /path/to/ATS/infra/docker-compose.override.yml .
docker compose up -d

# Execute database schema
psql -h localhost -p 5432 -U postgres -d postgres -f /path/to/ATS/infra/database/schema.sql
```

### 2. Node.js Intranet Backend
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your Supabase keys
npm test
npm start
```

Access the **Teacher Projector Display** at:
```
http://192.168.10.50:3000/teacher/display?classId=CS101
```

### 3. ESP32 Classroom Beacon
1. Open [`firmware/classroom_beacon/classroom_beacon.ino`](firmware/classroom_beacon/classroom_beacon.ino) in Arduino IDE.
2. Install library: **NimBLE-Arduino** by h2zero.
3. Flash to ESP32 board and mount inside classroom on 5V USB power.

### 4. Flutter Mobile Client
```bash
cd mobile
flutter pub get
flutter run
```

To build production release with code obfuscation:
```bash
flutter build apk --release --obfuscate --split-debug-info=./build/debug-info
```

---

## 📖 In-Depth Documentation

- [System Architecture (HLD / LLD)](docs/architecture.md)
- [Complete Production Setup Guide](docs/setup-guide.md)
- [Security Hardening & Threat Matrix](docs/security-hardening.md)
- [ESP32 BLE Beacon Calibration](docs/esp32-calibration.md)
- [Firmware Flashing Guide](firmware/classroom_beacon/README.md)
- [Backend Intranet Server Guide](backend/README.md)
- [Mobile Client Guide](mobile/README.md)

---

## 🔒 Security Disclosure

Please report any suspected cryptographic vulnerabilities or bypass techniques directly to the system administrators at `security@iiitdwd.ac.in`.

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
