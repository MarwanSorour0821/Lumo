# Generated migration to add 'medication' as a valid type choice

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('logging_app', '0005_ensure_reminder_times_column'),
    ]

    operations = [
        # No database changes needed - this is just updating the Python choices
        # The CharField doesn't have a database constraint, so we just need to
        # ensure the model reflects the new choice
    ]
