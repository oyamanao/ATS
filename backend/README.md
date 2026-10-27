# Attendance Backend (Node.js Express API)

Secure Intranet API server for the Cheat-Proof Indoor Attendance System. Runs strictly on the university local intranet subnet (e.g. `192.168.10.50:3000`) and serves as the cryptographic verification gate for all attendance records.

---

## 🔄 Evolution & Changelog (Past State vs. Current State)

| Component / Area | Past State | Current State (Work Done & Improved) |
|---|---|---|
| **Node.js Runtime** | Targeted older Node.js versions without modern LTS guards. | **Upgraded to Node.js 22 LTS** (`engines: >= 22.0.0`) with full CommonJS compatibility. |
| **Code Linting** | Deprecated ESLint config that failed under modern ESLint 9. | **Modern ESLint 9 Flat Config** (`eslint.config.js`) with custom globals, strict test globals, and rules. |
| **Teacher Projector Display** | Basic or placeholder display endpoint. | **Dynamic Live Projector Dashboard** (`/teacher/display`) rendering rolling 10s HMAC-SHA256 SVG QR codes with countdown progress bar. |
| **QR Payload Parsing** | Brittle URL parsing that altered class identifier casing and lacked scheme checks. | **Robust Protocol & Case-Preserving Parser** verifying strict `attendance://<classId>/<totp>` scheme while preserving uppercase/mixed-case class codes. |
| **Cryptographic Engine** | Basic validation logic without full end-to-end cryptographic tests. | **Hardware RSA-SHA256 Verification** using Node native `crypto` module + **HMAC-SHA256 TOTP** validation with ±1 window tolerance. |
| **Replay Protection** | Incomplete replay idempotency tracking in tests and handlers. | **Per-Student Replay Protection** logging to `processed_tokens` and rejecting duplicate tokens with automated 5-minute cleanup. |
| **Logging & Diagnostics** | Unformatted `console.log` statements without structured audit fields. | **Winston Structured Logger** (`src/utils/logger.js`) providing colorized timestamped output in development and structured JSON in production. |
| **Test Coverage & CI** | Missing WebSocket mocks and partial coverage. | **100% Jest Test Suite Coverage** across 28 unit tests and 6 test suites covering routes, services, middleware, and bootstrap logic. |

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
   └── Deconstructs: attendance://<classId>/<totpCode> (preserves casing)
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
   └── Queries processed_tokens: guarantees a rolling token cannot be used twice by the same student
   │
   ▼
8. Record Attendance & Token
   └── Atomically logs attendance and marks token as consumed
```

---

## 🚀 Getting Started

### Prerequisites
- Node.js $\ge 22.0.0$ LTS
- npm $\ge 10.0.0$
- Reachable Supabase / PostgreSQL instance (or running via Docker Compose)

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

### Running Tests & Linting

Run ESLint:
```bash
npm run lint
```

Run test suite with code coverage:
```bash
npm test
```
*(Runs all 28 Jest tests across 6 test suites).*
