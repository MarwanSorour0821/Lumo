-- Create subscriptions table for Stripe subscription management
-- 
-- Instructions:
-- 1. Open your Supabase Dashboard
-- 2. Go to SQL Editor
-- 3. Paste and run this entire script
-- 
-- Notes:
-- - This creates the subscriptions table with proper indexes and RLS policies
-- - The table references auth.users for user_id (must be UUID matching Supabase auth)
-- - RLS allows users to read their own subscriptions and service role to manage all

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'past_due', 'unpaid', 'trialing')),
    plan TEXT NOT NULL CHECK (plan IN ('monthly', 'yearly')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer_id ON subscriptions(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status) WHERE status = 'active';

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at on row updates
DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Policy: Users can read their own subscription
CREATE POLICY "Users can view their own subscription"
    ON subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Service role can do everything (for backend API)
-- Note: This allows your backend to insert/update subscriptions via service role key
CREATE POLICY "Service role can manage all subscriptions"
    ON subscriptions
    FOR ALL
    USING (auth.role() = 'service_role');

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON subscriptions TO authenticated;
GRANT ALL ON subscriptions TO service_role;

