from rest_framework import serializers
from .models import ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    """Serializer for chat messages."""
    
    class Meta:
        model = ChatMessage
        fields = ['id', 'role', 'content', 'created_at']
        read_only_fields = ['id', 'created_at']


class SendMessageSerializer(serializers.Serializer):
    """Serializer for sending a new message."""
    
    user_id = serializers.CharField(max_length=255)
    message = serializers.CharField(max_length=4000)


class GetHistorySerializer(serializers.Serializer):
    """Serializer for getting chat history."""
    
    user_id = serializers.CharField(max_length=255)
    minutes = serializers.IntegerField(default=30, min_value=1, max_value=1440)


class ClearHistorySerializer(serializers.Serializer):
    """Serializer for clearing chat history."""
    
    user_id = serializers.CharField(max_length=255)
