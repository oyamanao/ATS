# Infrastructure & Database Stack (`infra/`)

Production deployment configuration, container orchestration, reverse proxy gateway, and database schemas for the Cheat-Proof Indoor Attendance System (ATS).

---

## 🔄 Evolution & Changelog (Past State vs. Current State)

| Component / Area | Past State | Current State (Work Done & Improved) |
|---|---|---|
| **Container Architecture** | Disconnected container definitions with manual inter-service wiring. | **Unified Docker Compose Stack** (`docker-compose.yml` & `infra/docker-compose.yml`) orchestrating Postgres 16, PostgREST 12, GoTrue Auth 2.158, NGINX gateway, and ATS backend. |
| **Network Security** | Ports were broadly exposed across host interfaces. | **Zero-Trust Network Isolation**: All database and auth services communicate solely over an internal isolated bridge network (`ats-network`); only port `3000` is exposed to the university intranet. |
| **Unified Gateway** | Direct unproxied access or fragmented port mappings. | **Centralized NGINX Reverse Proxy** (`infra/gateway/nginx.conf`) consolidating PostgREST (`/rest/v1/`) and GoTrue Auth (`/auth/v1/`) on internal port `8000` with Docker internal DNS resolver (`127.0.0.11`). |
| **Database Schema** | Minimal schema lacking standard Supabase GoTrue authentication roles and types. | **Comprehensive PostgreSQL Schema** (`schema.sql` & `migrations/001_initial_schema.sql`) defining GoTrue enums (`factor_type`, `aal_level`), `auth.users`, and standard roles (`anon`, `authenticated`, `service_role`). |
| **Replay Attack Mitigation** | Token tables grew indefinitely without an automated purge strategy. | **Automated Cleanup Trigger**: PostgreSQL trigger procedure `cleanup_old_processed_tokens()` runs automatically on token insertion to purge expired tokens older than 5 minutes. |
| **Row Level Security (RLS)** | Unrestricted table permissions. | **Hardened RLS Policies**: Configured granular access control on `student_devices`, `processed_tokens`, and `attendance_logs` restricting read/write access to authorized service roles. |
| **Google Workspace SSO** | Unconfigured or manual OAuth setup. | **Modular OAuth Override** (`docker-compose.override.yml`) providing turnkey Google Workspace domain-locked authentication (`@iiitdwd.ac.in`). |

---

## 🏛️ Infrastructure Topology

```
Host / University Intranet (Port 3000)
       │
       ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        ats-backend (Node.js API)                       │
│                        Port: 3000 -> Intranet                          │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Internal Docker Network (ats-network)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        ats-gateway (NGINX Reverse Proxy)               │
│                        Port: 8000 (Internal Only)                      │
│      ├── /auth/v1/ ──► ats-auth (Supabase GoTrue v2.158.1 :9999)       │
│      └── /rest/v1/ ──► ats-postgrest (PostgREST v12.2.0 :3000)         │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Internal DB Connection (:5432)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        ats-postgres (PostgreSQL 16 Alpine)             │
│                        Port: 5432 (Internal Only)                      │
│                        Volume: ats_pgdata                              │
│                        Init: infra/database/schema.sql                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 Subdirectory Structure

```
infra/
├── docker-compose.yml              # Base production compose stack
├── docker-compose.override.yml     # Google OAuth configuration override
├── gateway/
│   └── nginx.conf                  # Unified internal reverse proxy configuration
└── database/
    ├── schema.sql                  # Complete PostgreSQL DDL, RLS, and cleanup triggers
    └── migrations/
        └── 001_initial_schema.sql  # Versioned migration for database initialization
```

---

## ⚡ Deployment Instructions

From the project root:

1. **Configure Environment:**
   ```bash
   cp .env.example .env
   ```
2. **Start the Stack:**
   ```bash
   docker compose up -d --build
   ```
3. **Verify Health:**
   ```bash
   docker compose ps
   curl http://localhost:3000/health
   ```
