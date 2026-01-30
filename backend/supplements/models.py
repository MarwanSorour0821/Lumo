"""
Supplement knowledge base: timing, food rules, and compatibility.
Maps to the existing `supplements` table (Supabase); do not run migrations.
"""
import uuid
from django.db import models
from django.contrib.postgres.fields import ArrayField


class Supplement(models.Model):
    """
    Read-only model for the curated supplements table.
    Used for lookup and scheduling rules; table is managed in Supabase.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, unique=True)
    aliases = ArrayField(models.CharField(max_length=255), default=list, blank=True)
    best_times = ArrayField(models.CharField(max_length=50), default=list, blank=True)
    with_food = models.BooleanField(default=False)
    empty_stomach = models.BooleanField(default=False)
    avoid_dairy = models.BooleanField(default=False)
    avoid_calcium = models.BooleanField(default=False)
    frequency_preference = models.CharField(max_length=20, default='once_daily')
    take_with = ArrayField(models.CharField(max_length=255), default=list, blank=True)
    dont_take_with = ArrayField(models.CharField(max_length=255), default=list, blank=True)
    spacing_hours = models.IntegerField(null=True, blank=True)
    description = models.TextField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    scientific_source = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'supplements'
        managed = False  # Table exists in Supabase; do not create/alter
        ordering = ['name']

    def __str__(self):
        return self.name
