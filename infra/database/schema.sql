-- =============================================================================
-- Cheat-Proof Attendance System — Database Schema
-- Supports both Self-Hosted Supabase and Direct PostgreSQL Deployments
-- =============================================================================

-- Ensure auth schema exists
CREATE SCHEMA IF NOT EXISTS auth;

-- Define core auth enums
DO $$ BEGIN
    CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Matches Supabase GoTrue users table definition
CREATE TABLE IF NOT EXISTS auth.users (
    instance_id           UUID NULL,
    id                    UUID NOT NULL UNIQUE,
    aud                   VARCHAR(255) NULL,
    "role"                VARCHAR(255) NULL,
    email                 VARCHAR(255) NULL UNIQUE,
    encrypted_password    VARCHAR(255) NULL,
    email_confirmed_at    TIMESTAMPTZ NULL,
    confirmed_at          TIMESTAMPTZ NULL,
    invited_at            TIMESTAMPTZ NULL,
    confirmation_token    VARCHAR(255) NULL,
    confirmation_sent_at  TIMESTAMPTZ NULL,
    recovery_token        VARCHAR(255) NULL,
    recovery_sent_at      TIMESTAMPTZ NULL,
    email_change_token_new VARCHAR(255) NULL,
    email_change          VARCHAR(255) NULL,
    email_change_sent_at  TIMESTAMPTZ NULL,
    last_sign_in_at       TIMESTAMPTZ NULL,
    raw_app_meta_data     JSONB NULL DEFAULT '{}'::jsonb,
    raw_user_meta_data    JSONB NULL DEFAULT '{}'::jsonb,
    is_super_admin        BOOLEAN NULL DEFAULT false,
    is_sso_user           BOOLEAN NOT NULL DEFAULT false,
    is_anonymous          BOOLEAN NOT NULL DEFAULT false,
    phone                 TEXT NULL,
    phone_confirmed_at    TIMESTAMPTZ NULL,
    deleted_at            TIMESTAMPTZ NULL,
    created_at            TIMESTAMPTZ NULL DEFAULT timezone('utc', now()),
    updated_at            TIMESTAMPTZ NULL DEFAULT timezone('utc', now()),
    CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- Ensure standard Supabase roles exist for PostgREST & Auth
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN;
    END IF;
END $$;

-- Allow postgres and authenticator to switch roles for PostgREST and Auth
GRANT anon, authenticated, service_role TO postgres;
GRANT anon, authenticated, service_role TO authenticator;

-- ---------------------------------------------------------------------------
-- Table: profiles
-- Maps student credentials to institutional profiles (name, roll number, role).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT NOT NULL,
    full_name   TEXT,
    roll_number TEXT,
    role        TEXT NOT NULL DEFAULT 'student',
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

-- ---------------------------------------------------------------------------
-- Table: student_devices
-- Maps each student account to their hardware-bound public key.
-- The private key NEVER leaves the student's device hardware security chip.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_devices (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email      TEXT NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

-- ---------------------------------------------------------------------------
-- Table: processed_tokens
-- Tracks each consumed TOTP token per student to prevent replay attacks.
-- Tokens older than 5 minutes are purged automatically.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.processed_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token      TEXT NOT NULL,
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT unique_user_processed_token UNIQUE (token, user_id)
);

-- ---------------------------------------------------------------------------
-- Table: attendance_logs
-- Immutable record of all successfully verified attendance events.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_logs (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    class_id  TEXT NOT NULL,
    email     TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

-- Grant appropriate permissions on auth schema
GRANT ALL PRIVILEGES ON SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA auth TO postgres;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA auth TO service_role;
GRANT SELECT ON TABLE auth.users TO anon, authenticated;

-- Grant appropriate permissions on public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.student_devices TO authenticated;
GRANT SELECT ON public.attendance_logs TO authenticated;

-- =============================================================================
-- Row Level Security (RLS)
-- =============================================================================
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_devices    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_tokens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_logs    ENABLE ROW LEVEL SECURITY;

-- Helper functions for RLS if not yet installed by auth system
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::UUID;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::TEXT;
$$ LANGUAGE sql STABLE;

DO $$
BEGIN
    -- Profiles: authenticated users can read profiles and manage their own
    EXECUTE 'CREATE POLICY "students_view_profiles" ON public.profiles FOR SELECT TO authenticated USING (true);';
    EXECUTE 'CREATE POLICY "students_manage_own_profile" ON public.profiles FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);';

    -- Students can view and register/update their own hardware device key
    EXECUTE 'CREATE POLICY "students_view_own_device" ON public.student_devices FOR SELECT TO authenticated USING (auth.uid() = user_id);';
    EXECUTE 'CREATE POLICY "students_manage_own_device" ON public.student_devices FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);';

    -- Students can view their own verified attendance logs
    EXECUTE 'CREATE POLICY "students_view_own_attendance" ON public.attendance_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);';

    -- Backend service role has full access to all tables
    EXECUTE 'CREATE POLICY "allow_service_role_profiles" ON public.profiles FOR ALL TO service_role USING (true) WITH CHECK (true);';
    EXECUTE 'CREATE POLICY "allow_service_role_devices" ON public.student_devices FOR ALL TO service_role USING (true) WITH CHECK (true);';
    EXECUTE 'CREATE POLICY "allow_service_role_tokens" ON public.processed_tokens FOR ALL TO service_role USING (true) WITH CHECK (true);';
    EXECUTE 'CREATE POLICY "allow_service_role_logs" ON public.attendance_logs FOR ALL TO service_role USING (true) WITH CHECK (true);';
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- Trigger: Auto-populate Profile on Auth Signup
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, roll_number)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'roll_number', '')
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
        roll_number = COALESCE(NULLIF(EXCLUDED.roll_number, ''), public.profiles.roll_number),
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Automated Token Cleanup
-- Removes TOTP tokens older than 5 minutes to keep the table lean.
-- Triggered after every INSERT into processed_tokens.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.delete_expired_tokens()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.processed_tokens
    WHERE created_at < NOW() - INTERVAL '5 minutes';
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_cleanup_tokens ON public.processed_tokens;
CREATE TRIGGER trigger_cleanup_tokens
    AFTER INSERT ON public.processed_tokens
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.delete_expired_tokens();

-- =============================================================================
-- Indexes for query performance
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_email
    ON public.profiles(email);

CREATE INDEX IF NOT EXISTS idx_profiles_roll_number
    ON public.profiles(roll_number);

CREATE INDEX IF NOT EXISTS idx_student_devices_user_id
    ON public.student_devices(user_id);

CREATE INDEX IF NOT EXISTS idx_student_devices_email
    ON public.student_devices(email);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_user_id
    ON public.attendance_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_class_id
    ON public.attendance_logs(class_id);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_user_class_time
    ON public.attendance_logs(user_id, class_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_processed_tokens_user_token
    ON public.processed_tokens(user_id, token);

CREATE INDEX IF NOT EXISTS idx_processed_tokens_created_at
    ON public.processed_tokens(created_at);
