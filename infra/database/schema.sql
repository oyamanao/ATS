-- =============================================================================
-- Cheat-Proof Attendance System — Database Schema
-- Run in your self-hosted Supabase SQL Editor
-- =============================================================================

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
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

-- ---------------------------------------------------------------------------
-- Table: processed_tokens
-- Tracks each consumed TOTP token to prevent replay attacks.
-- Tokens older than 5 minutes are purged automatically.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.processed_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token      TEXT NOT NULL UNIQUE,
    user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
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

-- =============================================================================
-- Row Level Security (RLS)
-- =============================================================================
ALTER TABLE public.student_devices    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processed_tokens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_logs    ENABLE ROW LEVEL SECURITY;

-- Students may only read their own registered device record
CREATE POLICY "students_view_own_device"
    ON public.student_devices
    FOR SELECT
    USING (auth.uid() = user_id);

-- Students may only read their own attendance history
CREATE POLICY "students_view_own_attendance"
    ON public.attendance_logs
    FOR SELECT
    USING (auth.uid() = user_id);

-- processed_tokens is backend-only (service role key). No client policies needed.

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
CREATE INDEX IF NOT EXISTS idx_attendance_logs_user_id
    ON public.attendance_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_class_id
    ON public.attendance_logs(class_id);

CREATE INDEX IF NOT EXISTS idx_processed_tokens_created_at
    ON public.processed_tokens(created_at);
