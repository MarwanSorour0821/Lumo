"""
API view for supplement scheduling via AI.
"""
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

import logging
from .services import SuppsAIOpenAIService
from logging_app.models import FoodSupplementItem
from subscriptions.views import get_supabase_client


class SupplementScheduleView(APIView):
    """
    POST endpoint: returns AI-generated supplement schedule for the authenticated user.
    Only available to users with valid subscriptions.
    Extensive logging for request, supplements, and OpenAI response.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logger = logging.getLogger("suppsAI")
        user = request.user
        logger.info("\n" + "="*60)
        logger.info(f"Received supplement schedule request for user: {user.id}")
        # Check subscription using Supabase (active or trialing)
        user_id = getattr(user, 'user_id', None) or getattr(user, 'id', None)
        supabase = get_supabase_client()
        response = supabase.table('subscriptions').select('id').eq('user_id', user_id).in_('status', ['active', 'trialing']).execute()
        has_active_subscription = bool(response.data and len(response.data) > 0)
        logger.info(f"Subscription status: {has_active_subscription}")
        if not has_active_subscription:
            logger.warning("User does not have an active subscription.")
            return Response({"error": "Subscription required."}, status=403)
        # Get supplements
        supplements = list(FoodSupplementItem.objects.filter(user=user, is_archived=False).values_list('name', flat=True))
        logger.info(f"User supplements: {supplements}")
        if not supplements:
            logger.warning("No supplements found for user.")
            return Response({"error": "No supplements found."}, status=400)
        # Get schedule from AI
        ai_service = SuppsAIOpenAIService()
        try:
            schedule = ai_service.get_supplement_schedule(supplements)
            logger.info(f"Final supplement schedule for user {user.id}: {schedule}")
            return Response({"schedule": schedule})
        except Exception as e:
            logger.error(f"Error generating supplement schedule: {str(e)}")
            return Response({"error": "Failed to generate schedule."}, status=500)
