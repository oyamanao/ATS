# Attendance Backend (Node.js Express API)

Secure Intranet API server for the Cheat-Proof Indoor Attendance System. Runs strictly on the university local intranet subnet (e.g. `192.168.10.50:3000`) and serves as the cryptographic verification gate for all attendance records.

---

## 🛡️ Security Verification Pipeline

When a client hits `POST /api/attendance/mark`:

```
Client POST { qrPayload, signature }
   │
   ▼
1. verifySession Middleware
   ├── Verifies Supabase JWT access token
   └── Asserts email domain ends with @iiitdwd.ac.in
   │
   ▼
2. rateLimiter Middleware
   └── Enforces max 5 attempts per 30s window per IP
   │
   ▼
3. QR Payload Parse
   └── Deconstructs: attendance://<classId>/<totpCode>
   │
   ▼
4. Dynamic TOTP Verification
   └── Validates 6-digit TOTP against SHA-256 algorithm with 10s period (allows ±1 window)
   │
   ▼
5. Device Public Key Lookup
   └── Fetches student's hardware-bound RSA public key from Supabase DB
   │
   ▼
6. Cryptographic RSA-SHA256 Signature Verification
   └── Confirms signature matches qrPayload using the hardware public key
   │
   ▼
7. Idempotency Check
   └── Queries processed_tokens: guarantees a rolling token cannot be used twice
   │
   ▼
8. Record Attendance & Token
   └── Atomically logs attendance and marks token as consumed
```

---

## 🚀 Getting Started

### Prerequisites
- Node.js $\ge 20.0.0$
- npm $\ge 10.0.0$
- Self-hosted Supabase instance reachable on the local network

### Installation
```bash
cd backend
npm install
```

### Configuration
Copy the environment template and configure values:
```bash
cp .env.example .env
```

| Variable | Description | Default |
|---|---|---|
| `PORT` | API listen port | `3000` |
| `HOST` | Subnet interface to bind | `0.0.0.0` (or `192.168.10.50`) |
| `SUPABASE_URL` | Local Supabase gateway URL | `http://192.168.10.50:8000` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role secret | *Required* |
| `ALLOWED_EMAIL_DOMAIN` | Permitted institutional email domain | `@iiitdwd.ac.in` |
| `SHARED_CLASS_SECRET` | Base32 TOTP secret shared with classroom display | `KVKXG2LEMYFA====` |
| `TOTP_INTERVAL` | Rolling token lifespan in seconds | `10` |

### Running the Server

Development mode with auto-reload:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

### Running Tests & Coverage
```bash
npm test
```
