from rest_framework import serializers
from .models import ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    """Serializer for chat messages."""
    
    class Meta:
        model = ChatMessage
        fields = ['id', 'role', 'content', 'message_type', 'file_name', 'file_size', 'created_at']
        read_only_fields = ['id', 'created_at']


class SendMessageSerializer(serializers.Serializer):
    """Serializer for sending a new text message."""
    
    user_id = serializers.CharField(max_length=255)
    message = serializers.CharField(max_length=4000)


class SendFileMessageSerializer(serializers.Serializer):
    """Serializer for sending a file message (image or PDF)."""
    
    user_id = serializers.CharField(max_length=255)
    message = serializers.CharField(max_length=4000, required=False, allow_blank=True)
    # File will be handled separately via request.FILES


class GetHistorySerializer(serializers.Serializer):
    """Serializer for getting chat history."""
    
    user_id = serializers.CharField(max_length=255)
    minutes = serializers.IntegerField(default=30, min_value=1, max_value=1440)


class ClearHistorySerializer(serializers.Serializer):
    """Serializer for clearing chat history."""
    
    user_id = serializers.CharField(max_length=255)


