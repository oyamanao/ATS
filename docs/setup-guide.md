# Production Deployment & Setup Guide

This guide covers complete end-to-end setup and deployment of the Cheat-Proof Indoor Attendance System.

---

## 1. Network & Infrastructure Architecture

```
Campus Router / Gateway
  │
  ├── Local Intranet Subnet: 192.168.10.0/24
  │     ├── Server Host: 192.168.10.50
  │     │     ├── Docker Supabase Gateway: http://192.168.10.50:8000
  │     │     └── Node.js Intranet API:     http://192.168.10.50:3000
  │     │
  │     └── Classroom Access Points:
  │           └── AP 1 BSSID: 00:14:22:01:23:45
  │           └── AP 2 BSSID: 00:14:22:01:23:46
  │
  └── Firewall Rules:
        ├── Inbound WAN to 192.168.10.50:3000 -> REJECT (Intranet Only)
        └── Outbound from 192.168.10.50 to Google OAuth -> ALLOW
```

---

## 2. Self-Hosted Supabase Deployment

### Step 2.1 — Clone Supabase Docker Configuration
```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
```

### Step 2.2 — Apply Google OAuth Override
Copy [`infra/docker-compose.override.yml`](../infra/docker-compose.override.yml) into the `supabase/docker/` directory:

```yaml
version: '3.8'
services:
  auth:
    environment:
      GOTRUE_EXTERNAL_GOOGLE_ENABLED: "true"
      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID: "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
      GOTRUE_EXTERNAL_GOOGLE_SECRET: "YOUR_GOOGLE_CLIENT_SECRET"
      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI: "http://192.168.10.50:8000/auth/v1/callback"
      GOTRUE_URI_ALLOW_LIST: "attendanceapp://login-callback"
      GOTRUE_EXTERNAL_EMAIL_ENABLED: "false"
      GOTRUE_MAILER_AUTOCONFIRM: "false"
```

### Step 2.3 — Start Docker Containers
```bash
docker compose up -d
```

### Step 2.4 — Execute Database Schema
Open Supabase Studio at `http://192.168.10.50:8000` (or via `psql` to `localhost:5432`):
Run the script in [`infra/database/schema.sql`](../infra/database/schema.sql).

---

## 3. Node.js Backend Deployment

### Step 3.1 — Setup Node.js 20+ and PM2
```bash
cd backend
npm install
npm install -g pm2
```

### Step 3.2 — Configure Environment
```bash
cp .env.example .env
```
Update `.env` with:
```env
SUPABASE_URL=http://192.168.10.50:8000
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_FROM_SUPABASE
ALLOWED_EMAIL_DOMAIN=@iiitdwd.ac.in
SHARED_CLASS_SECRET=KVKXG2LEMYFA====
TOTP_INTERVAL=10
PORT=3000
HOST=0.0.0.0
```

### Step 3.3 — Launch with PM2 Process Manager
```bash
pm2 start server.js --name "ats-backend" --time
pm2 save
pm2 startup
```

Verify health check:
```bash
curl http://192.168.10.50:3000/health
# {"status":"ok","time":"..."}
```

---

## 4. ESP32 Classroom Beacon Setup

1. Open Arduino IDE 2.x with the `esp32` board manager installed.
2. Install **NimBLE-Arduino** library via Arduino Library Manager.
3. Open [`firmware/classroom_beacon/classroom_beacon.ino`](../firmware/classroom_beacon/classroom_beacon.ino).
4. Assign a unique UUID per classroom and set building/room numbers:
   ```cpp
   #define BEACON_UUID "B9407F30-F5F8-466E-AFF9-25556B57FE6D"
   #define BUILDING_ID 1
   #define ROOM_NUMBER 101
   ```
5. Plug ESP32 via USB and flash at `921600` baud.
6. Mount the board at the front of the classroom plugged into a 5V USB wall adapter.

---

## 5. Flutter Mobile App Build

### Step 5.1 — Configure Constants
Open [`mobile/lib/config/constants.dart`](../mobile/lib/config/constants.dart) and configure campus coordinates, classroom BSSIDs, and beacon UUID:

```dart
static const String localBackendUrl = 'http://192.168.10.50:3000';
static const String supabaseLocalUrl = 'http://192.168.10.50:8000';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
static const double campusLat = 15.3920;
static const double campusLng = 75.0255;
static const String targetBeaconUUID = 'B9407F30-F5F8-466E-AFF9-25556B57FE6D';
```

### Step 5.2 — Build Obfuscated Release APK
```bash
cd mobile
flutter pub get
flutter build apk --release \
  --obfuscate \
  --split-debug-info=./build/debug-info
```

Distribute the APK to students via internal university portal or MDM.

---

## 6. Classroom Projection Display

During lecture, the instructor opens the live projector screen:
```
http://192.168.10.50:3000/teacher/display?classId=CS101
```
The screen renders the rolling 10-second QR code and countdown bar for students to scan.
