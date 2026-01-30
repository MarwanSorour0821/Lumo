"""
Serializers for supplement lookup API responses.
"""
from rest_framework import serializers
from .models import Supplement


class SupplementSerializer(serializers.ModelSerializer):
    """Full supplement record for lookup responses."""

    class Meta:
        model = Supplement
        fields = [
            'id',
            'name',
            'aliases',
            'best_times',
            'with_food',
            'empty_stomach',
            'avoid_dairy',
            'avoid_calcium',
            'frequency_preference',
            'take_with',
            'dont_take_with',
            'spacing_hours',
            'description',
            'notes',
            'scientific_source',
            'is_active',
        ]
        read_only_fields = fields
