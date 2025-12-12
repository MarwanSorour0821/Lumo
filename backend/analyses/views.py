from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import Analysis
from .serializers import AnalysisSerializer, AnalysisListSerializer, CreateAnalysisSerializer
from .authentication import SupabaseAuthentication


class AnalysisListCreateView(APIView):
    """
    GET: List all analyses for the authenticated user
    POST: Create a new analysis
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get all analyses for the authenticated user."""
        user_id = request.user.user_id
        analyses = Analysis.objects.filter(user_id=user_id).order_by('-created_at')
        serializer = AnalysisListSerializer(analyses, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """Create a new analysis for the authenticated user."""
        serializer = CreateAnalysisSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response(
                {'error': 'Invalid data', 'details': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create the analysis with the authenticated user's ID
        analysis = Analysis.objects.create(
            user_id=request.user.user_id,
            parsed_data=serializer.validated_data['parsed_data'],
            analysis=serializer.validated_data['analysis'],
            title=serializer.validated_data.get('title')
        )
        
        response_serializer = AnalysisSerializer(analysis)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)


class AnalysisDetailView(APIView):
    """
    GET: Retrieve a single analysis
    DELETE: Delete an analysis
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]

    def get_object(self, analysis_id, user_id):
        """Get analysis object ensuring it belongs to the user."""
        try:
            return Analysis.objects.get(id=analysis_id, user_id=user_id)
        except Analysis.DoesNotExist:
            return None

    def get(self, request, analysis_id):
        """Get a single analysis by ID."""
        analysis = self.get_object(analysis_id, request.user.user_id)
        
        if not analysis:
            return Response(
                {'error': 'Analysis not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = AnalysisSerializer(analysis)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def delete(self, request, analysis_id):
        """Delete an analysis by ID."""
        analysis = self.get_object(analysis_id, request.user.user_id)
        
        if not analysis:
            return Response(
                {'error': 'Analysis not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        analysis.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
