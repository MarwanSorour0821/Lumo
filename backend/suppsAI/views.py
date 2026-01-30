"""
API view for supplement scheduling (Phase 2: deterministic scheduler).
"""
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

import logging
from .scheduler import build_schedule
from logging_app.models import FoodSupplementItem
from subscriptions.views import get_supabase_client

logger = logging.getLogger("suppsAI")


class SupplementScheduleView(APIView):
    """
    POST endpoint: returns supplement schedule for the authenticated user.
    Uses the supplements knowledge base + deterministic scheduler (no OpenAI).
    Requires valid subscription.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        logger.info("\n" + "="*60)
        logger.info("Supplement schedule request for user: %s", user.id)
        user_id = getattr(user, 'user_id', None) or getattr(user, 'id', None)
        supabase = get_supabase_client()
        response = supabase.table('subscriptions').select('id').eq('user_id', user_id).in_('status', ['active', 'trialing']).execute()
        has_active_subscription = bool(response.data and len(response.data) > 0)
        logger.info("Subscription status: %s", has_active_subscription)
        if not has_active_subscription:
            logger.warning("User does not have an active subscription.")
            return Response({"error": "Subscription required."}, status=403)
        supplement_names = list(
            FoodSupplementItem.objects.filter(user=user, is_archived=False).values_list('name', flat=True)
        )
        logger.info("User supplements: %s", supplement_names)
        if not supplement_names:
            logger.warning("No supplements found for user.")
            return Response({"error": "No supplements found."}, status=400)
        try:
            schedule, unknown = build_schedule(supplement_names)
            logger.info("Schedule for user %s: %s; unknown: %s", user.id, schedule, unknown)
            return Response({"schedule": schedule, "unknown": unknown})
        except Exception as e:
            logger.exception("Error generating supplement schedule")
            return Response({"error": "Failed to generate schedule."}, status=500)


class SupplementScheduleTestView(APIView):
    """
    POST with body {"names": ["Magnesium", "Iron", ...]} -> returns schedule (no auth).
    Use this to test Phase 2 scheduler only. Do not use in production for sensitive data.
    """
    permission_classes = []  # No auth for testing
    authentication_classes = []

    def post(self, request):
        names = request.data.get("names")
        if not isinstance(names, list):
            return Response({"error": 'Body must include "names" (list of supplement names).'}, status=400)
        if not names:
            return Response({"schedule": {}, "unknown": []})
        try:
            schedule, unknown = build_schedule(names)
            return Response({"schedule": schedule, "unknown": unknown})
        except Exception as e:
            logger.exception("Schedule test failed")
            return Response({"error": str(e)}, status=500)
