-- Add notification settings columns to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS email_notifications BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS push_notifications BOOLEAN DEFAULT true;
