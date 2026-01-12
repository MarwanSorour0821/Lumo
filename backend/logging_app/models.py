import uuid
from django.db import models
from django.contrib.postgres.fields import ArrayField


def default_reminder_days():
    """Default reminder days (all days of the week)"""
    return [0, 1, 2, 3, 4, 5, 6]


class FoodSupplementItem(models.Model):
    """
    Model representing a food or supplement item that users can log.
    Maps to the 'food_supplement_items' table in Supabase PostgreSQL.
    """
    TYPE_CHOICES = [
        ('food', 'Food'),
        ('supplement', 'Supplement'),
        ('medication', 'Medication'),
    ]
    
    FREQUENCY_CHOICES = [
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
        ('as_needed', 'As Needed'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id = models.UUIDField(db_index=True)
    name = models.CharField(max_length=255)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='supplement')
    description = models.TextField(blank=True, null=True)
    
    # Frequency settings
    frequency = models.CharField(max_length=20, choices=FREQUENCY_CHOICES, default='daily')
    times_per_week = models.IntegerField(default=7)
    
    # Reminder settings
    reminder_enabled = models.BooleanField(default=False)
    reminder_times = models.JSONField(default=list, blank=True, db_column='reminder_times')  # List of time strings, e.g., ["09:00:00", "14:00:00", "21:00:00"]
    reminder_days = ArrayField(
        models.IntegerField(),
        default=default_reminder_days,
        blank=True
    )
    
    # Taken tracking
    last_taken_at = models.DateTimeField(blank=True, null=True)
    
    # Start and end dates for medication course
    start_date = models.DateField(blank=True, null=True)
    end_date = models.DateField(blank=True, null=True)

    # Metadata
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'food_supplement_items'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.type}) for user {self.user_id}"


class FoodSupplementLog(models.Model):
    """
    Model representing an individual intake log entry.
    Maps to the 'food_supplement_logs' table in Supabase PostgreSQL.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id = models.UUIDField(db_index=True)
    item = models.ForeignKey(FoodSupplementItem, on_delete=models.CASCADE, related_name='logs')
    logged_at = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True, null=True)
    quantity = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'food_supplement_logs'
        ordering = ['-logged_at']

    def __str__(self):
        return f"Log for {self.item.name} at {self.logged_at}"


class FoodSupplementBiomarkerImpact(models.Model):
    """
    Model representing the impact of a food/supplement on biomarkers.
    Maps to the 'food_supplement_biomarker_impacts' table in Supabase PostgreSQL.
    """
    IMPACT_TYPE_CHOICES = [
        ('positive', 'Positive'),
        ('negative', 'Negative'),
        ('neutral', 'Neutral'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    item = models.ForeignKey(FoodSupplementItem, on_delete=models.CASCADE, related_name='biomarker_impacts')
    biomarker_name = models.CharField(max_length=255)
    impact_type = models.CharField(max_length=20, choices=IMPACT_TYPE_CHOICES)
    impact_description = models.TextField(blank=True, null=True)
    impact_score = models.IntegerField(default=0)  # -100 to 100
    scientific_source = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'food_supplement_biomarker_impacts'
        ordering = ['-impact_score']

    def __str__(self):
        return f"{self.item.name} -> {self.biomarker_name}: {self.impact_type}"
