# Migration to ensure reminder_times column exists and Django state is correct
# This fixes the issue where Django might be querying reminder_time instead of reminder_times

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('logging_app', '0004_fix_reminder_times_rename'),
    ]

    operations = [
        migrations.RunSQL(
            sql="""
                -- Ensure the reminder_times column exists (idempotent)
                -- If reminder_time exists, rename it to reminder_times
                DO $$
                BEGIN
                    IF EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'food_supplement_items' 
                        AND column_name = 'reminder_time'
                    ) THEN
                        ALTER TABLE food_supplement_items 
                        RENAME COLUMN reminder_time TO reminder_times;
                    END IF;
                    
                    -- Ensure reminder_times is JSONB type
                    IF EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_name = 'food_supplement_items' 
                        AND column_name = 'reminder_times'
                        AND data_type != 'jsonb'
                    ) THEN
                        ALTER TABLE food_supplement_items 
                        ALTER COLUMN reminder_times TYPE jsonb 
                        USING CASE 
                            WHEN reminder_times IS NULL THEN '[]'::jsonb
                            WHEN reminder_times::text = '' THEN '[]'::jsonb
                            ELSE reminder_times::jsonb
                        END;
                    END IF;
                END $$;
            """,
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
