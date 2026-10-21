-- =============================================================================
-- Migration 001: Initial Schema
-- Supports both Self-Hosted Supabase and Direct PostgreSQL Deployments
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS auth;

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

CREATE TABLE IF NOT EXISTS auth.users (
    instance_id           UUID NULL,
    id                    UUID NOT NULL UNIQUE,
    aud                   VARCHAR(255) NULL,
    "role"                VARCHAR(255) NULL,
    email                 VARCHAR(255) NULL UNIQUE,
    encrypted_password    VARCHAR(255) NULL,
    confirmed_at          TIMESTAMPTZ NULL,
    invited_at            TIMESTAMPTZ NULL,
    confirmation_token    VARCHAR(255) NULL,
    confirmation_sent_at  TIMESTAMPTZ NULL,
    recovery_token        VARCHAR(255) NULL,
    recovery_sent_at      TIMESTAMPTZ NULL,
    email_change_token    VARCHAR(255) NULL,
    email_change          VARCHAR(255) NULL,
    email_change_sent_at  TIMESTAMPTZ NULL,
    last_sign_in_at       TIMESTAMPTZ NULL,
    raw_app_meta_data     JSONB NULL,
    raw_user_meta_data    JSONB NULL,
    is_super_admin        BOOLEAN NULL,
    created_at            TIMESTAMPTZ NULL DEFAULT timezone('utc', now()),
    updated_at            TIMESTAMPTZ NULL DEFAULT timezone('utc', now()),
    CONSTRAINT users_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.student_devices (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email      TEXT NOT NULL,
    public_key TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.processed_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token      TEXT NOT NULL UNIQUE,
    user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.attendance_logs (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    class_id  TEXT NOT NULL,
    email     TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.student_devices    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_tokens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_logs    ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.role', true), '')::TEXT;
$$ LANGUAGE sql STABLE;

DO $$
BEGIN
    EXECUTE 'CREATE POLICY "students_view_own_device" ON public.student_devices FOR SELECT USING (auth.uid() = user_id);';
    EXECUTE 'CREATE POLICY "students_view_own_attendance" ON public.attendance_logs FOR SELECT USING (auth.uid() = user_id);';
    EXECUTE 'CREATE POLICY "allow_all_service_role_devices" ON public.student_devices FOR ALL USING (true);';
    EXECUTE 'CREATE POLICY "allow_all_service_role_tokens" ON public.processed_tokens FOR ALL USING (true);';
    EXECUTE 'CREATE POLICY "allow_all_service_role_logs" ON public.attendance_logs FOR ALL USING (true);';
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

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

CREATE INDEX IF NOT EXISTS idx_attendance_logs_user_id
    ON public.attendance_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_class_id
    ON public.attendance_logs(class_id);

CREATE INDEX IF NOT EXISTS idx_processed_tokens_created_at
    ON public.processed_tokens(created_at);
