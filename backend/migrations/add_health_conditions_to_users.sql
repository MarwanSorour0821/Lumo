-- Migration: Add health_conditions column to users table
-- This stores an array of health conditions selected during signup

-- Add health_conditions column as JSONB array
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS health_conditions JSONB DEFAULT '[]'::jsonb;

-- Add a comment to the column
COMMENT ON COLUMN public.users.health_conditions IS 'Array of health conditions selected by user during signup (e.g., ["High blood pressure", "Type 2 diabetes"])';

-- Optional: Add an index for querying health conditions
CREATE INDEX IF NOT EXISTS idx_users_health_conditions ON public.users USING GIN (health_conditions);
