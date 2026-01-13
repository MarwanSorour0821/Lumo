# Generated migration for dose-level taken tracking

from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('logging_app', '0006_add_medication_type'),
    ]

    operations = [
        migrations.CreateModel(
            name='DoseTakenStatus',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('user_id', models.UUIDField(db_index=True)),
                ('date', models.DateField(db_index=True)),
                ('time_index', models.IntegerField()),
                ('taken_at', models.DateTimeField(blank=True, null=True)),
                ('is_taken', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('item', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='dose_statuses', to='logging_app.foodsupplementitem')),
            ],
            options={
                'db_table': 'dose_taken_status',
                'ordering': ['time_index'],
                'unique_together': {('item', 'date', 'time_index')},
            },
        ),
    ]
