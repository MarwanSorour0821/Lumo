# Generated migration for adding start_date and end_date to FoodSupplementItem

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('logging_app', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='foodsupplementitem',
            name='start_date',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='foodsupplementitem',
            name='end_date',
            field=models.DateField(blank=True, null=True),
        ),
    ]
