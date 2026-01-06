from django.contrib import admin
from .models import FoodSupplementItem, FoodSupplementLog, FoodSupplementBiomarkerImpact


@admin.register(FoodSupplementItem)
class FoodSupplementItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'type', 'user_id', 'frequency', 'reminder_enabled', 'created_at']
    list_filter = ['type', 'frequency', 'reminder_enabled', 'is_archived']
    search_fields = ['name', 'user_id']
    ordering = ['-created_at']


@admin.register(FoodSupplementLog)
class FoodSupplementLogAdmin(admin.ModelAdmin):
    list_display = ['item', 'user_id', 'quantity', 'logged_at']
    list_filter = ['logged_at']
    search_fields = ['item__name', 'user_id']
    ordering = ['-logged_at']


@admin.register(FoodSupplementBiomarkerImpact)
class FoodSupplementBiomarkerImpactAdmin(admin.ModelAdmin):
    list_display = ['item', 'biomarker_name', 'impact_type', 'impact_score']
    list_filter = ['impact_type']
    search_fields = ['item__name', 'biomarker_name']
    ordering = ['-impact_score']
