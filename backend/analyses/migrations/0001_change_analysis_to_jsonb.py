# Generated manually to change analysis column from text to jsonb

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        # No dependencies since table already exists in Supabase
    ]

    operations = [
        migrations.RunSQL(
            # Change the column type from text to jsonb
            # For existing text data that isn't valid JSON, set to NULL
            # The application will need to re-analyze old records if needed
            sql="""
                -- Set any existing non-JSON text to NULL (they'll need to be re-analyzed)
                UPDATE analyses 
                SET analysis = NULL 
                WHERE analysis IS NOT NULL 
                AND analysis != ''
                AND NOT (analysis ~ '^[\s]*\{.*\}[\s]*$');
                
                -- Change the column type from text to jsonb
                ALTER TABLE analyses 
                ALTER COLUMN analysis TYPE jsonb 
                USING CASE 
                    WHEN analysis IS NULL OR analysis = '' THEN NULL::jsonb
                    ELSE analysis::jsonb
                END;
            """,
            reverse_sql="""
                ALTER TABLE analyses 
                ALTER COLUMN analysis TYPE text 
                USING CASE
                    WHEN analysis IS NULL THEN NULL::text
                    ELSE analysis::text
                END;
            """,
        ),
    ]

