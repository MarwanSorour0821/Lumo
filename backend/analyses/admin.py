from django.contrib import admin
from .models import Analysis


@admin.register(Analysis)
class AnalysisAdmin(admin.ModelAdmin):
    list_display = ['id', 'user_id', 'title', 'created_at', 'updated_at']
    list_filter = ['created_at']
    search_fields = ['user_id', 'title']
    readonly_fields = ['id', 'created_at', 'updated_at']
    ordering = ['-created_at']
