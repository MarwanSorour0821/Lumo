from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from .serializers import BloodTestUploadSerializer, BloodTestAnalysisSerializer
from .services import OpenAIService
import json


class AnalyzeBloodTestView(APIView):
    parser_classes = (MultiPartParser, FormParser)
    
    def post(self, request, *args, **kwargs):
        """
        Endpoint to upload and analyze blood test image/PDF
        """
        serializer = BloodTestUploadSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(
                {'error': 'Invalid file upload', 'details': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        uploaded_file = serializer.validated_data['file']
        
        # Validate file type
        allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'application/pdf']
        if uploaded_file.content_type not in allowed_types:
            return Response(
                {'error': f'Invalid file type. Allowed types: {", ".join(allowed_types)}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Initialize OpenAI service
            ai_service = OpenAIService()
            
            # Step 1: Parse the image with GPT-4o
            print("\n=== STEP 1: Parsing blood test image with GPT-4o ===")
            parsed_data = ai_service.parse_blood_test_image(uploaded_file)
            print("Parsed Data:")
            print(json.dumps(parsed_data, indent=2))
            
            # Step 2: Analyze with GPT-5.1
            print("\n=== STEP 2: Analyzing with GPT-5.1 ===")
            analysis = ai_service.analyze_blood_test(parsed_data)
            print("\n=== ANALYSIS RESULT ===")
            print(analysis)
            print("\n" + "="*50 + "\n")
            
            # Prepare response
            response_data = {
                'parsed_data': parsed_data,
                'analysis': analysis,
                'created_at': timezone.now()
            }
            
            response_serializer = BloodTestAnalysisSerializer(response_data)
            
            return Response(
                response_serializer.data,
                status=status.HTTP_200_OK
            )
            
        except json.JSONDecodeError as e:
            return Response(
                {'error': 'Failed to parse blood test data', 'details': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        except Exception as e:
            return Response(
                {'error': 'Failed to analyze blood test', 'details': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class HealthCheckView(APIView):
    """Simple health check endpoint"""
    
    def get(self, request):
        return Response({'status': 'ok', 'service': 'AI Analysis'})
