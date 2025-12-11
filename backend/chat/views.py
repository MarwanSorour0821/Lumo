import uuid
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser
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
    Send a text message to the chat AI and get a response.
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


class SendFileMessageView(APIView):
    """
    Send a file (image or PDF) to the chat AI and get a response.
    Accepts multipart form data with 'file', 'user_id', and optional 'message'.
    """
    parser_classes = [MultiPartParser, FormParser]
    
    # Allowed file types
    ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/jpg']
    ALLOWED_PDF_TYPES = ['application/pdf']
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
    
    def post(self, request):
        user_id = request.data.get('user_id')
        message = request.data.get('message', '')
        file = request.FILES.get('file')
        
        # Validate required fields
        if not user_id:
            return Response({
                'success': False,
                'error': 'user_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if not file:
            return Response({
                'success': False,
                'error': 'file is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate file size
        if file.size > self.MAX_FILE_SIZE:
            return Response({
                'success': False,
                'error': f'File size exceeds maximum allowed ({self.MAX_FILE_SIZE // (1024*1024)}MB)'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Determine file type
        content_type = file.content_type
        is_image = content_type in self.ALLOWED_IMAGE_TYPES
        is_pdf = content_type in self.ALLOWED_PDF_TYPES
        
        if not is_image and not is_pdf:
            return Response({
                'success': False,
                'error': f'Unsupported file type: {content_type}. Allowed: images (JPEG, PNG, GIF, WebP) and PDF.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Generate unique filename
            ext = file.name.split('.')[-1] if '.' in file.name else ('jpg' if is_image else 'pdf')
            unique_filename = f"{uuid.uuid4()}.{ext}"

            # Read file bytes
            file_bytes = file.read()

            # Process based on file type
            if is_image:
                response = chat_service.get_response_with_image(
                    user_id=user_id,
                    image_bytes=file_bytes,
                    file_name=unique_filename,
                    file_size=file.size,
                    user_message=message if message else None,
                    content_type=content_type
                )
            else:  # PDF
                response = chat_service.get_response_with_pdf(
                    user_id=user_id,
                    pdf_bytes=file_bytes,
                    file_name=unique_filename,
                    file_size=file.size,
                    user_message=message if message else None,
                    content_type=content_type
                )
            
            return Response({
                'success': True,
                'response': response,
                'file_type': 'image' if is_image else 'pdf',
                'file_name': file.name
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            import traceback
            error_trace = traceback.format_exc()
            print(f"Error in SendFileMessageView: {error_trace}")  # Print to console for debugging
            return Response({
                'success': False,
                'error': str(e),
                'traceback': error_trace
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
