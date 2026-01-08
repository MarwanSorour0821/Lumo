-- Migration to add last_taken_at column to food_supplement_items table
-- Run this in Supabase SQL Editor if the table already exists

ALTER TABLE food_supplement_items
ADD COLUMN IF NOT EXISTS last_taken_at TIMESTAMP WITH TIME ZONE;

-- Add comment for documentation
COMMENT ON COLUMN food_supplement_items.last_taken_at IS 'Timestamp of when the item was last marked as taken';
