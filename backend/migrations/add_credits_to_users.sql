-- Migration: Add credits column to users table
-- Run this in Supabase SQL Editor

-- Add credits column to users table with default of 0
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS credits INTEGER DEFAULT 0 NOT NULL;

-- Create a function to safely add credits (prevents negative values)
CREATE OR REPLACE FUNCTION add_credits(user_uuid UUID, credits_to_add INTEGER)
RETURNS INTEGER AS $$
DECLARE
    new_credits INTEGER;
BEGIN
    UPDATE users 
    SET credits = credits + credits_to_add
    WHERE id = user_uuid
    RETURNING credits INTO new_credits;
    
    RETURN new_credits;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to deduct credits (returns false if insufficient)
CREATE OR REPLACE FUNCTION deduct_credit(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    current_credits INTEGER;
BEGIN
    SELECT credits INTO current_credits FROM users WHERE id = user_uuid;
    
    IF current_credits IS NULL OR current_credits < 1 THEN
        RETURN FALSE;
    END IF;
    
    UPDATE users SET credits = credits - 1 WHERE id = user_uuid;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create index for faster credit lookups
CREATE INDEX IF NOT EXISTS idx_users_credits ON users(id, credits);

-- Create credit_purchases table to track all credit purchases
CREATE TABLE IF NOT EXISTS credit_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    credits_purchased INTEGER NOT NULL,
    amount_paid DECIMAL(10,2) NOT NULL,
    stripe_payment_intent_id TEXT,
    stripe_session_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for credit purchases
CREATE INDEX IF NOT EXISTS idx_credit_purchases_user ON credit_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_purchases_session ON credit_purchases(stripe_session_id);

-- Enable RLS on credit_purchases
ALTER TABLE credit_purchases ENABLE ROW LEVEL SECURITY;

-- Users can only view their own purchases
CREATE POLICY "Users can view own credit purchases"
    ON credit_purchases FOR SELECT
    USING (auth.uid() = user_id);

-- Only service role can insert/update (via backend)
CREATE POLICY "Service role can manage credit purchases"
    ON credit_purchases FOR ALL
    USING (auth.role() = 'service_role');
