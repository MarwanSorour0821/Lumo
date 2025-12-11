from django.db import models
from django.utils import timezone
from datetime import timedelta


class ChatMessage(models.Model):
    """
    Stores chat messages between users and the AI assistant.
    Messages are automatically cleaned up after 30 minutes.
    """
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
    ]
    
    # Using string for user_id to match Supabase UUID format
    user_id = models.CharField(max_length=255, db_index=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    
    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['user_id', 'created_at']),
        ]
    
    def __str__(self):
        return f"{self.role}: {self.content[:50]}..."
    
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
        """
        cutoff_time = timezone.now() - timedelta(minutes=minutes)
        queryset = cls.objects.filter(created_at__lt=cutoff_time)
        
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        deleted_count, _ = queryset.delete()
        return deleted_count
    
    @classmethod
    def get_conversation_history(cls, user_id: str, minutes: int = 30):
        """
        Get the conversation history formatted for OpenAI API.
        Returns a list of message dicts with 'role' and 'content'.
        """
        messages = cls.get_user_messages(user_id, minutes)
        return [
            {'role': msg.role, 'content': msg.content}
            for msg in messages
        ]
