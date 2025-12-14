from django.contrib import admin
from .models import ChatMessage


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'user_id', 'role', 'message_type', 'short_content', 'file_name', 'storage_path', 'created_at']
    list_filter = ['role', 'message_type', 'created_at']
    search_fields = ['user_id', 'content', 'file_name', 'storage_path']
    ordering = ['-created_at']
    readonly_fields = ['created_at']
    
    def short_content(self, obj):
        if not obj.content:
            return '-'
        return obj.content[:50] + '...' if len(obj.content) > 50 else obj.content
    short_content.short_description = 'Content'



