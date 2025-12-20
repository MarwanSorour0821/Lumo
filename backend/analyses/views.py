import os
import stripe
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import Analysis
from .serializers import AnalysisSerializer, AnalysisListSerializer, CreateAnalysisSerializer
from .authentication import SupabaseAuthentication
from chat.models import ChatMessage
from supabase import create_client

# Initialize Stripe (only if key is available, don't fail if not set)
if os.environ.get('STRIPE_SECRET_KEY'):
    stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')


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


class DeleteAccountView(APIView):
    """
    DELETE: Delete all user data (analyses, chat messages, subscription)
    Note: This does NOT delete the Supabase auth user - that must be done from the frontend
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        """Delete all data associated with the authenticated user."""
        user_id = request.user.user_id
        
        try:
            # Cancel Stripe subscription if exists
            subscription_cancelled = False
            supabase_url = os.environ.get("SUPABASE_URL") or os.environ.get("SUPABASE_PROJECT_URL")
            supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
            
            if supabase_url and supabase_key and stripe.api_key:
                try:
                    supabase = create_client(supabase_url, supabase_key)
                    # Get user's subscription
                    subscription_response = supabase.table('subscriptions').select('stripe_subscription_id').eq('user_id', user_id).eq('status', 'active').execute()
                    
                    if subscription_response.data and len(subscription_response.data) > 0:
                        stripe_subscription_id = subscription_response.data[0].get('stripe_subscription_id')
                        if stripe_subscription_id:
                            # Cancel the subscription in Stripe
                            stripe.Subscription.delete(stripe_subscription_id)
                            subscription_cancelled = True
                            
                            # Update subscription status in Supabase
                            supabase.table('subscriptions').update({
                                'status': 'cancelled',
                            }).eq('stripe_subscription_id', stripe_subscription_id).execute()
                except Exception as sub_error:
                    # Log error but don't fail the entire deletion if subscription cancellation fails
                    print(f'Warning: Failed to cancel subscription during account deletion: {str(sub_error)}')
            
            # Delete all analyses for the user
            analyses_count = Analysis.objects.filter(user_id=user_id).delete()[0]
            
            # Delete all chat messages for the user (this also deletes associated files)
            chat_messages = ChatMessage.objects.filter(user_id=user_id)
            # Delete files first
            for msg in chat_messages:
                msg.delete_file()
            chat_count = chat_messages.delete()[0]
            
            return Response(
                {
                    'message': 'Account data deleted successfully',
                    'analyses_deleted': analyses_count,
                    'chat_messages_deleted': chat_count,
                    'subscription_cancelled': subscription_cancelled,
                },
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': f'Failed to delete account data: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
