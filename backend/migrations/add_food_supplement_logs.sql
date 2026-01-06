-- Migration: Create food and supplement logging tables
-- Run this in Supabase SQL Editor

-- Create enum for log types
DO $$ BEGIN
    CREATE TYPE log_type AS ENUM ('food', 'supplement');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create enum for frequency
DO $$ BEGIN
    CREATE TYPE frequency_type AS ENUM ('daily', 'weekly', 'monthly', 'as_needed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create the main food_supplement_items table (stores the items users can log)
CREATE TABLE IF NOT EXISTS food_supplement_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type log_type NOT NULL DEFAULT 'supplement',
    description TEXT,
    -- Frequency settings
    frequency frequency_type DEFAULT 'daily',
    times_per_week INTEGER DEFAULT 7, -- 1-7 for weekly, used when frequency is 'weekly'
    -- Reminder settings
    reminder_enabled BOOLEAN DEFAULT FALSE,
    reminder_time TIME, -- Time of day for reminder
    reminder_days INTEGER[] DEFAULT ARRAY[0,1,2,3,4,5,6], -- Days of week (0=Sunday, 6=Saturday)
    -- Metadata
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create the logs table (individual intake records)
CREATE TABLE IF NOT EXISTS food_supplement_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES food_supplement_items(id) ON DELETE CASCADE,
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    quantity TEXT, -- e.g., "1 pill", "500mg", "1 serving"
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create biomarker impacts table (stores the impact of items on biomarkers)
CREATE TABLE IF NOT EXISTS food_supplement_biomarker_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES food_supplement_items(id) ON DELETE CASCADE,
    biomarker_name TEXT NOT NULL,
    impact_type TEXT NOT NULL CHECK (impact_type IN ('positive', 'negative', 'neutral')),
    impact_description TEXT,
    impact_score INTEGER DEFAULT 0 CHECK (impact_score >= -100 AND impact_score <= 100), -- -100 to 100
    scientific_source TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_food_supplement_items_user_id ON food_supplement_items(user_id);
CREATE INDEX IF NOT EXISTS idx_food_supplement_items_type ON food_supplement_items(type);
CREATE INDEX IF NOT EXISTS idx_food_supplement_items_archived ON food_supplement_items(is_archived);
CREATE INDEX IF NOT EXISTS idx_food_supplement_logs_user_id ON food_supplement_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_food_supplement_logs_item_id ON food_supplement_logs(item_id);
CREATE INDEX IF NOT EXISTS idx_food_supplement_logs_logged_at ON food_supplement_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_food_supplement_biomarker_impacts_item_id ON food_supplement_biomarker_impacts(item_id);

-- Enable Row Level Security
ALTER TABLE food_supplement_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_supplement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_supplement_biomarker_impacts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for food_supplement_items
CREATE POLICY "Users can view their own items" ON food_supplement_items
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own items" ON food_supplement_items
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own items" ON food_supplement_items
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own items" ON food_supplement_items
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for food_supplement_logs
CREATE POLICY "Users can view their own logs" ON food_supplement_logs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own logs" ON food_supplement_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own logs" ON food_supplement_logs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own logs" ON food_supplement_logs
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for biomarker_impacts (users can view impacts for their items)
CREATE POLICY "Users can view impacts for their items" ON food_supplement_biomarker_impacts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM food_supplement_items 
            WHERE food_supplement_items.id = food_supplement_biomarker_impacts.item_id 
            AND food_supplement_items.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert impacts for their items" ON food_supplement_biomarker_impacts
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM food_supplement_items 
            WHERE food_supplement_items.id = food_supplement_biomarker_impacts.item_id 
            AND food_supplement_items.user_id = auth.uid()
        )
    );

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_food_supplement_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS trigger_update_food_supplement_items_updated_at ON food_supplement_items;
CREATE TRIGGER trigger_update_food_supplement_items_updated_at
    BEFORE UPDATE ON food_supplement_items
    FOR EACH ROW
    EXECUTE FUNCTION update_food_supplement_items_updated_at();

-- Grant necessary permissions
GRANT ALL ON food_supplement_items TO authenticated;
GRANT ALL ON food_supplement_logs TO authenticated;
GRANT ALL ON food_supplement_biomarker_impacts TO authenticated;
