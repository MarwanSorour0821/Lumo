# Generated migration for logging_app

from django.db import migrations, models
import django.contrib.postgres.fields
import uuid


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='FoodSupplementItem',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('user_id', models.UUIDField(db_index=True)),
                ('name', models.CharField(max_length=255)),
                ('type', models.CharField(choices=[('food', 'Food'), ('supplement', 'Supplement')], default='supplement', max_length=20)),
                ('description', models.TextField(blank=True, null=True)),
                ('frequency', models.CharField(choices=[('daily', 'Daily'), ('weekly', 'Weekly'), ('monthly', 'Monthly'), ('as_needed', 'As Needed')], default='daily', max_length=20)),
                ('times_per_week', models.IntegerField(default=7)),
                ('reminder_enabled', models.BooleanField(default=False)),
                ('reminder_time', models.TimeField(blank=True, null=True)),
                ('reminder_days', django.contrib.postgres.fields.ArrayField(base_field=models.IntegerField(), blank=True, default=list, size=None)),
                ('last_taken_at', models.DateTimeField(blank=True, null=True)),
                ('is_archived', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'db_table': 'food_supplement_items',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='FoodSupplementLog',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('user_id', models.UUIDField(db_index=True)),
                ('logged_at', models.DateTimeField(auto_now_add=True)),
                ('notes', models.TextField(blank=True, null=True)),
                ('quantity', models.CharField(blank=True, max_length=100, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('item', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='logs', to='logging_app.foodsupplementitem')),
            ],
            options={
                'db_table': 'food_supplement_logs',
                'ordering': ['-logged_at'],
            },
        ),
        migrations.CreateModel(
            name='FoodSupplementBiomarkerImpact',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('biomarker_name', models.CharField(max_length=255)),
                ('impact_type', models.CharField(choices=[('positive', 'Positive'), ('negative', 'Negative'), ('neutral', 'Neutral')], max_length=20)),
                ('impact_description', models.TextField(blank=True, null=True)),
                ('impact_score', models.IntegerField(default=0)),
                ('scientific_source', models.TextField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('item', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='biomarker_impacts', to='logging_app.foodsupplementitem')),
            ],
            options={
                'db_table': 'food_supplement_biomarker_impacts',
                'ordering': ['-impact_score'],
            },
        ),
    ]
