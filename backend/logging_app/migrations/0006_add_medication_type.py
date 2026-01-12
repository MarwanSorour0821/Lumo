# Generated migration to add 'medication' as a valid type choice

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('logging_app', '0005_ensure_reminder_times_column'),
    ]

    operations = [
        # Add 'medication' to the PostgreSQL enum type 'log_type'
        # The error message shows: "invalid input value for enum log_type: \"medication\""
        migrations.RunSQL(
            # Add 'medication' to the enum if it doesn't exist
            sql="""
                DO $$ 
                BEGIN
                    -- Check if enum 'log_type' exists
                    IF EXISTS (
                        SELECT 1 FROM pg_type WHERE typname = 'log_type'
                    ) THEN
                        -- Check if 'medication' already exists in the enum
                        IF NOT EXISTS (
                            SELECT 1 FROM pg_enum 
                            WHERE enumlabel = 'medication' 
                            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'log_type')
                        ) THEN
                            -- Add 'medication' to the enum
                            ALTER TYPE log_type ADD VALUE 'medication';
                        END IF;
                    END IF;
                END $$;
            """,
            reverse_sql="""
                -- Cannot remove enum values in PostgreSQL, so reverse is a no-op
                -- PostgreSQL does not support removing enum values
            """
        ),
    ]
