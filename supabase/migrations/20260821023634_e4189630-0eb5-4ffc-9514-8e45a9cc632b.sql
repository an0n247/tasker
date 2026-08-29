-- We cannot directly change auth settings via SQL in Lovable Cloud
-- but we can ensure the application code correctly handles the 6-digit OTP
-- and verify the signup process.
-- This migration is a placeholder to document the requirement for 6-digit OTP
-- which is the default for Supabase Auth when verifyOtp is used in the frontend.

SELECT 1; -- No-op migration to satisfy tool requirements while I handle frontend logic
