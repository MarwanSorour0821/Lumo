from rest_framework import serializers
from django.utils import timezone
from datetime import datetime, time
from .models import FoodSupplementItem, FoodSupplementLog, FoodSupplementBiomarkerImpact


class FoodSupplementBiomarkerImpactSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodSupplementBiomarkerImpact
        fields = [
            'id', 'biomarker_name', 'impact_type', 'impact_description',
            'impact_score', 'scientific_source', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class FoodSupplementLogSerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='item.name', read_only=True)
    item_type = serializers.CharField(source='item.type', read_only=True)
    
    class Meta:
        model = FoodSupplementLog
        fields = [
            'id', 'user_id', 'item_id', 'item_name', 'item_type',
            'logged_at', 'notes', 'quantity', 'created_at'
        ]
        read_only_fields = ['id', 'user_id', 'created_at', 'item_name', 'item_type']


class FoodSupplementItemSerializer(serializers.ModelSerializer):
    biomarker_impacts = FoodSupplementBiomarkerImpactSerializer(many=True, read_only=True)
    recent_logs = serializers.SerializerMethodField()
    log_count = serializers.SerializerMethodField()
    is_taken_today = serializers.SerializerMethodField()

    class Meta:
        model = FoodSupplementItem
        fields = [
            'id', 'user_id', 'name', 'type', 'description',
            'frequency', 'times_per_week',
            'reminder_enabled', 'reminder_times', 'reminder_days',
            'start_date', 'end_date',
            'last_taken_at', 'is_taken_today',
            'is_archived', 'created_at', 'updated_at',
            'biomarker_impacts', 'recent_logs', 'log_count'
        ]
        read_only_fields = ['id', 'user_id', 'created_at', 'updated_at']

    def get_recent_logs(self, obj):
        # Get the 5 most recent logs
        recent = obj.logs.all()[:5]
        return FoodSupplementLogSerializer(recent, many=True).data

    def get_log_count(self, obj):
        return obj.logs.count()

    def get_is_taken_today(self, obj):
        """Check if the item was marked as taken today"""
        if not obj.last_taken_at:
            return False
        today = timezone.now().date()
        return obj.last_taken_at.date() == today


class FoodSupplementItemCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating new items"""
    class Meta:
        model = FoodSupplementItem
        fields = [
            'name', 'type', 'description',
            'frequency', 'times_per_week',
            'reminder_enabled', 'reminder_times', 'reminder_days',
            'start_date', 'end_date'
        ]
    
    def validate_type(self, value):
        """Validate that type is one of the allowed choices"""
        allowed_types = ['food', 'supplement', 'medication']
        if value not in allowed_types:
            raise serializers.ValidationError(
                f"Type must be one of {allowed_types}, got '{value}'"
            )
        return value


class QuickLogSerializer(serializers.Serializer):
    """Serializer for quick logging via voice or text"""
    input_text = serializers.CharField(help_text="Voice transcription or text input")
    

class BiomarkerImpactRequestSerializer(serializers.Serializer):
    """Serializer for requesting biomarker impact analysis"""
    item_name = serializers.CharField()
    item_type = serializers.CharField(default='supplement')
