import os
from django.db import models
from django.utils import timezone
from datetime import timedelta
from .supabase_client import get_supabase_client


class ChatMessage(models.Model):
    """
    Stores chat messages between users and the AI assistant.
    Messages are automatically cleaned up after 30 minutes.
    Supports text messages and file attachments (images/PDFs).
    """
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
    ]
    
    MESSAGE_TYPE_CHOICES = [
        ('text', 'Text'),
        ('image', 'Image'),
        ('pdf', 'PDF'),
    ]
    
    # Using string for user_id to match Supabase UUID format
    user_id = models.CharField(max_length=255, db_index=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField(blank=True, default='')
    message_type = models.CharField(max_length=10, choices=MESSAGE_TYPE_CHOICES, default='text')
    
    # File attachment fields
    file_name = models.CharField(max_length=255, blank=True, null=True)
    storage_path = models.CharField(max_length=500, blank=True, null=True)
    file_size = models.IntegerField(blank=True, null=True)  # Size in bytes
    
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    
    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['user_id', 'created_at']),
        ]
    
    def __str__(self):
        if self.message_type == 'text':
            return f"{self.role}: {self.content[:50]}..."
        return f"{self.role}: [{self.message_type}] {self.file_name}"
    
    def delete_file(self):
        """Delete the associated file from Supabase storage if it exists."""
        if self.storage_path:
            try:
                client = get_supabase_client()
                bucket = ChatStorage.bucket_name()
                client.storage.from_(bucket).remove([self.storage_path])
            except Exception:
                # Ignore storage deletion errors to avoid blocking DB cleanup
                pass

    def delete(self, *args, **kwargs):
        """Override delete to also remove the file."""
        self.delete_file()
        super().delete(*args, **kwargs)

    @classmethod
    def get_user_messages(cls, user_id: str, minutes: int = 30):
        """
        Get messages for a user within the last N minutes.
        Also cleans up old messages.
        """
        # First, clean up old messages
        cls.cleanup_old_messages(user_id, minutes)
        
        # Then return current messages
        cutoff_time = timezone.now() - timedelta(minutes=minutes)
        return cls.objects.filter(
            user_id=user_id,
            created_at__gte=cutoff_time
        ).order_by('created_at')
    
    @classmethod
    def cleanup_old_messages(cls, user_id: str = None, minutes: int = 30):
        """
        Delete messages older than the specified minutes.
        If user_id is provided, only clean up that user's messages.
        Also deletes associated files.
        """
        cutoff_time = timezone.now() - timedelta(minutes=minutes)
        queryset = cls.objects.filter(created_at__lt=cutoff_time)
        
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Collect storage paths before delete
        storage_paths = [msg.storage_path for msg in queryset if msg.storage_path]
        deleted_count, _ = queryset.delete()

        # Delete storage objects best-effort
        if storage_paths:
            try:
                client = get_supabase_client()
                bucket = ChatStorage.bucket_name()
                client.storage.from_(bucket).remove(storage_paths)
            except Exception:
                pass

        return deleted_count
    
    @classmethod
    def get_conversation_history(cls, user_id: str, minutes: int = 30):
        """
        Get the conversation history formatted for OpenAI API.
        Returns a list of message dicts with 'role' and 'content'.
        For file messages, includes a description of the attachment.
        """
        messages = cls.get_user_messages(user_id, minutes)
        history = []
        
        for msg in messages:
            if msg.message_type == 'text':
                history.append({'role': msg.role, 'content': msg.content})
            else:
                # For file messages, include the content (AI analysis) or description
                content = msg.content if msg.content else f"[{msg.message_type.upper()}: {msg.file_name}]"
                history.append({'role': msg.role, 'content': content})
        
        return history


class ChatStorage:
    """
    Helper for storage settings.
    """
    @staticmethod
    def bucket_name() -> str:
        # Default bucket name
        return os.getenv('CHAT_STORAGE_BUCKET', 'chat-uploads')

