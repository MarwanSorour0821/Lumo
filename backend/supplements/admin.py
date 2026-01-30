from django.contrib import admin
from .models import Supplement


@admin.register(Supplement)
class SupplementAdmin(admin.ModelAdmin):
    list_display = ['name', 'is_active', 'frequency_preference']
    list_filter = ['is_active', 'with_food', 'empty_stomach']
    search_fields = ['name']
    readonly_fields = ['id', 'created_at', 'updated_at']

    class Meta:
        # Table is managed in Supabase; admin is read-only
        pass
