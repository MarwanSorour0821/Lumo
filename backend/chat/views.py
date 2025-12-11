from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import (
    ChatMessageSerializer,
    SendMessageSerializer,
    GetHistorySerializer,
    ClearHistorySerializer
)
from .services import chat_service
from .models import ChatMessage


class SendMessageView(APIView):
    """
    Send a message to the chat AI and get a response.
    """
    
    def post(self, request):
        serializer = SendMessageSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        user_id = serializer.validated_data['user_id']
        message = serializer.validated_data['message']
        
        try:
            response = chat_service.get_response(user_id, message)
            
            return Response({
                'success': True,
                'response': response
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ChatHistoryView(APIView):
    """
    Get chat history for a user.
    """
    
    def post(self, request):
        serializer = GetHistorySerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        user_id = serializer.validated_data['user_id']
        minutes = serializer.validated_data.get('minutes', 30)
        
        try:
            messages = ChatMessage.get_user_messages(user_id, minutes)
            message_serializer = ChatMessageSerializer(messages, many=True)
            
            return Response({
                'success': True,
                'messages': message_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ClearHistoryView(APIView):
    """
    Clear chat history for a user.
    """
    
    def post(self, request):
        serializer = ClearHistorySerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        user_id = serializer.validated_data['user_id']
        
        try:
            deleted_count = chat_service.clear_conversation(user_id)
            
            return Response({
                'success': True,
                'deleted_count': deleted_count
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
