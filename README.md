# Cheat-Proof Indoor Attendance System (ATS)

[![Backend CI](https://github.com/iiitdwd/ats/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/iiitdwd/ats/actions/workflows/backend-ci.yml)
[![Flutter CI](https://github.com/iiitdwd/ats/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/iiitdwd/ats/actions/workflows/flutter-ci.yml)
![Node Version](https://img.shields.io/badge/Node.js-22%20LTS-green.svg)
![Flutter Version](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg)
![Docker Compose](https://img.shields.io/badge/Docker-Compose%20v2%2B-blue.svg)
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

## 🚀 Project Evolution: What Has Been Done & Changed

The ATS codebase has undergone end-to-end development, modernization, hardening, and testing. Below is an overview of completed implementations and recent architectural enhancements:

### 1. Backend Intranet API & Teacher Display (`backend/`)
- **Node.js 22 LTS & Modern ESLint**: Upgraded to Node.js 22 runtime; configured ESLint 9 flat configuration with comprehensive environment globals and linting rules.
- **Dynamic Teacher Display (`/teacher/display`)**: Live projector endpoint rendering dynamic 10-second rolling TOTP QR codes (`attendance://<classId>/<totp>`) with countdown progress bars and automated SVG refresh.
- **Robust QR Scheme & URI Parsing**: Fixed case-sensitivity retention for class identifiers and added strict protocol verification (`attendance://`).
- **Cryptographic Verification Pipeline**:
  - Validates rolling HMAC-SHA256 TOTP tokens against configured time windows (`totpService.js`).
  - Verifies hardware RSA-SHA256 digital signatures using Node.js native `crypto` module (`signatureService.js`).
- **Replay Protection & Token Idempotency**: Records each consumed token in `processed_tokens` per student to strictly block duplicate token submission.
- **Structured Logging & Diagnostics**: Integrated Winston logging with colorized console output in development and structured JSON output for production audit trails.
- **Rate Limiting & Security Guards**: Implemented `express-rate-limit` to prevent brute-force attacks and locked API interactions to intranet origin.
- **100% Test Coverage**: Complete Jest test suite covering routes, services, middleware, and bootstrap logic (all 28 tests passing).

### 2. Infrastructure & Database Stack (`infra/` & `docker-compose.yml`)
- **Self-Contained Docker Stack**: Unified PostgreSQL 16 Alpine, PostgREST v12.2.0, Supabase GoTrue Auth v2.158.1, NGINX Gateway, and ATS Node.js backend.
- **Zero-Trust Network Isolation**: Containers communicate over an internal isolated bridge network (`ats-network`); only port `3000` is exposed to the local intranet host.
- **NGINX Gateway (`infra/gateway/nginx.conf`)**: Centralized internal reverse proxy routing `/auth/v1/` to GoTrue and `/rest/v1/` to PostgREST.
- **Database Schema & RLS Policies (`infra/database/schema.sql`)**:
  - Full relational schema covering `auth.users`, `public.student_devices`, `public.processed_tokens`, and `public.attendance_logs`.
  - Configured PostgreSQL Row-Level Security (RLS) policies and standard Supabase roles (`anon`, `authenticated`, `service_role`).
  - Automated database cleanup procedure (`cleanup_old_processed_tokens`) running on trigger to purge tokens older than 5 minutes.

### 3. Mobile Client Application (`mobile/`)
- **Flutter 3.24+ & Modern Toolchain**: Refactored for modern Flutter and Dart versions with Kotlin DSL build configuration (`build.gradle.kts`) and Gradle 9.x compatibility.
- **Android v1 Embedding Elimination**: Fully removed legacy, deprecated Android v1 embedding code from vendored plugins (`packages/flutter_beacon`), resolving build failures and modern AGP compatibility.
- **Hardware Sensor Services Hardening**:
  - `gps_service.dart`: High-accuracy GPS fixes, mock location detection flags, and permission fallbacks.
  - `wifi_service.dart`: Safe BSSID extraction and classroom AP allowlist validation.
  - `ble_service.dart`: Targeted UUID ranging with RSSI threshold filtering (`> -70 dBm`) and timeout loops.
  - `biometric_service.dart`: Secure Enclave / Android KeyStore RSA-2048 keypair generation and biometric signature creation.
- **Modular Screen Architecture**: Complete screens for Google Auth Login (`login_screen.dart`), Device Registration (`registration_screen.dart`), Home Verification Dashboard (`home_screen.dart`), and Live QR Scanner (`qr_scan_screen.dart`).
- **Production Build Hardening**: Configured release APK builds with symbol obfuscation and split debug info (`--obfuscate --split-debug-info`).

### 4. ESP32 Classroom Beacon Firmware (`firmware/`)
- **NimBLE-Arduino Migration**: Re-architected firmware from classic Bluedroid BLE stack to `NimBLE-Arduino` (>= 1.4.0), significantly reducing RAM usage and flash size.
- **RF Power Tuning for Anti-Bleed**: Tuned BLE transmission power to `ESP_PWR_LVL_N12` (-12 dBm) with a calibrated -59 dBm reference at 1 meter, ensuring radio signals do not penetrate corridor walls.
- **FreeRTOS Low-Power Yield**: Utilizes `vTaskDelay(portMAX_DELAY)` in `loop()` to eliminate CPU busy-waiting and prevent watchdog timer resets.
- **Visual Diagnostics**: Added boot double-blink LED indicator on GPIO 2 to verify correct deployment and active advertising.

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
│   ├── package.json                   # Dependencies & scripts
│   ├── eslint.config.js               # Modern ESLint 9 flat configuration
│   ├── jest.config.js                 # Jest test runner setup
│   ├── src/
│   │   ├── config/supabase.js         # Supabase client connector
│   │   ├── middleware/                # JWT verification & rate limiting
│   │   ├── routes/                    # Attendance submission & teacher display
│   │   ├── services/                  # TOTP validation & RSA signature verification
│   │   └── utils/logger.js            # Winston structured logger
│   └── tests/                         # Jest test suites (100% coverage, 28 tests)
│
├── mobile/                            # Flutter Client (Android & iOS)
│   ├── pubspec.yaml                   # Flutter dependencies
│   ├── lib/
│   │   ├── config/constants.dart      # Campus coordinates, BSSID allowlist, beacon UUID
│   │   ├── models/                    # Data transfer models
│   │   ├── services/                  # GPS, Wi-Fi, BLE, Biometric & Attendance orchestrator
│   │   ├── screens/                   # Login, Home, Registration & QR Scanner
│   │   └── widgets/                   # Status card, multi-step progress indicator, buttons
│   ├── packages/flutter_beacon/       # Modernized BLE beacon ranging plugin
│   ├── android/                       # Kotlin DSL Gradle build scripts & AndroidManifest
│   └── ios/                           # Info.plist with CoreLocation, BLE & Face ID keys
│
├── firmware/                          # ESP32 Microcontroller Firmware
│   ├── libraries.txt                  # Arduino IDE board manager & library specs
│   └── classroom_beacon/
│       ├── classroom_beacon.ino       # NimBLE iBeacon transmitter (-12 dBm tuned)
│       └── README.md                  # Arduino IDE flashing & wiring instructions
│
├── infra/                             # Deployment Infrastructure & Database
│   ├── docker-compose.yml             # Production compose stack
│   ├── docker-compose.override.yml    # Supabase Google OAuth configuration
│   ├── gateway/nginx.conf             # Unified reverse proxy gateway
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

## ⚡ Getting Started Locally

### Prerequisites

| Component | Software Needed |
| :--- | :--- |
| **Full Stack / Infra** | [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Docker Engine + Docker Compose) |
| **Backend API** | [Node.js](https://nodejs.org/) (>= 22.0.0 LTS) and `npm` |
| **Mobile App** | [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.24) & Android SDK |
| **Hardware Beacon** | [Arduino IDE 2.x](https://www.arduino.cc/en/software) with `esp32` board core & `NimBLE-Arduino` |

---

### Step 1: Environment Configuration

Create the local environment files from the provided templates:

```bash
# Root environment (used by Docker Compose)
cp .env.example .env

# Backend environment (used when running backend directly)
cp backend/.env.example backend/.env
```

Key environment variables in `.env`:
- `APP_PUBLIC_URL`: URL where the backend is reached (default: `http://localhost:3000`).
- `JWT_SECRET`: Secret key for token signing (minimum 32 characters).
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key for internal database queries.
- `SHARED_CLASS_SECRET`: Base32 secret for rolling HMAC-SHA256 TOTP tokens.
- `TOTP_INTERVAL`: Validity interval in seconds (default: `10`).

---

### Step 2: Run the Full Stack with Docker (Recommended)

From the project root:

```bash
docker compose up -d --build
```

This launches all containers:
- `ats-postgres`: PostgreSQL 16 database with initial schema.
- `ats-postgREST`: PostgREST API service.
- `ats-auth`: Supabase GoTrue authentication microservice.
- `ats-gateway`: NGINX unified reverse proxy.
- `ats-backend`: Express Intranet API & Teacher Projector.

**Check container status:**
```bash
docker compose ps
```

**Teacher Projector Screen:**
Open in any browser:
```text
http://localhost:3000/teacher/display?classId=CS101
```

---

### Step 3: Run Backend Independently (Without Docker)

If you prefer running only the Node.js API server locally:

```bash
cd backend
npm install
npm test
npm start
```

Health check verification:
```bash
curl http://localhost:3000/health
# Response: {"status":"ok","time":"..."}
```

---

### Step 4: Run the Flutter Mobile App

1. Connect an Android smartphone (with USB Debugging enabled) or start an emulator.
2. Launch the app:

```bash
cd mobile
flutter pub get
flutter run
```

To build an obfuscated production release APK:

```bash
flutter build apk --release --obfuscate --split-debug-info=./build/debug-info
```

> **Note on Hardware Sensors**: An emulator cannot scan physical BLE iBeacons or connect to physical classroom Wi-Fi BSSIDs. For full end-to-end verification of layers 2, 3, and 4, test with a physical Android device.

---

### Step 5: Flash the ESP32 Classroom Beacon

1. Open [`firmware/classroom_beacon/classroom_beacon.ino`](firmware/classroom_beacon/classroom_beacon.ino) in Arduino IDE 2.x.
2. In Arduino Library Manager, install: **NimBLE-Arduino** (by h2zero).
3. Connect the ESP32 via USB and select **Board: "ESP32 Dev Module"** and the assigned **COM Port**.
4. Set upload speed to `921600` baud and click **Upload**.
5. Upon boot, the on-board LED will double-blink to confirm active BLE advertising.

---

## 🧪 Testing & Verification

Run the automated test suites locally:

### Backend Unit & Integration Tests (Jest)
```bash
cd backend
npm test
```
*Executes all 28 test cases across 6 test suites covering TOTP verification, RSA signatures, rate limiting, session auth, and attendance submission.*

### Mobile Client Unit & Widget Tests (Flutter)
```bash
cd mobile
flutter test
```
*Validates serialization models, error code handling, widget rendering, and configuration fallbacks.*

---

## 📖 In-Depth Documentation

Detailed guides and specifications are available in the [`docs/`](docs/) directory:

- [System Architecture (HLD / LLD)](docs/architecture.md): Detailed protocol flows, class designs, and threat models.
- [Complete Production Setup Guide](docs/setup-guide.md): Campus network topology, firewall rules, and deployment instructions.
- [Security Hardening & Threat Matrix](docs/security-hardening.md): Attack vectors, mitigation strategies, and anti-tamper measures.
- [ESP32 BLE Beacon Calibration](docs/esp32-calibration.md): Signal attenuation formulas, RSSI surveys, and power tuning sheets.
- [Firmware Flashing Guide](firmware/classroom_beacon/README.md): ESP32 pinouts, baud rates, and library installation.
- [Backend Intranet Server Guide](backend/README.md): Express routes, middleware, and environment variables.
- [Mobile Client Guide](mobile/README.md): Permissions, keystore integration, and APK generation.

---

## 🔒 Security Disclosure

Please report any suspected cryptographic vulnerabilities or bypass techniques directly to the system administrators at `security@iiitdwd.ac.in`.

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
