"""
Supplement lookup API (Phase 1: data foundation).
"""
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from .models import Supplement
from .serializers import SupplementSerializer
from .services import get_supplement_by_name, get_supplements_by_names


class SupplementLookupView(APIView):
    """
    GET ?name=Vitamin+D3  -> single supplement or 404
    POST { "names": ["Magnesium", "Vitamin D3", "Unknown Thing"] } -> list of supplements + unknown names
    """

    def get(self, request):
        name = request.query_params.get('name', '').strip()
        if not name:
            return Response(
                {'error': 'Query parameter "name" is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        supplement = get_supplement_by_name(name)
        if supplement is None:
            return Response(
                {'found': False, 'name': name, 'message': 'Supplement not found in knowledge base.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response({
            'found': True,
            'supplement': SupplementSerializer(supplement).data,
        })

    def post(self, request):
        names = request.data.get('names')
        if names is None:
            return Response(
                {'error': 'Body must include "names" (list of supplement names).'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(names, list):
            return Response(
                {'error': '"names" must be a list of strings.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        results, unknown = get_supplements_by_names(names)
        supplements = [SupplementSerializer(s).data if s else None for s in results]
        return Response({
            'supplements': supplements,
            'unknown': unknown,
        })
