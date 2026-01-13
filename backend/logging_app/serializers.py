from rest_framework import serializers
from django.utils import timezone
from datetime import datetime, time
from .models import FoodSupplementItem, FoodSupplementLog, FoodSupplementBiomarkerImpact, DoseTakenStatus


class DoseTakenStatusSerializer(serializers.ModelSerializer):
    """Serializer for individual dose taken status"""
    time = serializers.SerializerMethodField()

    class Meta:
        model = DoseTakenStatus
        fields = ['id', 'time_index', 'time', 'is_taken', 'taken_at']
        read_only_fields = ['id', 'taken_at']

    def get_time(self, obj):
        """Get the actual time string from the parent item's reminder_times"""
        if obj.item and obj.item.reminder_times and obj.time_index < len(obj.item.reminder_times):
            return obj.item.reminder_times[obj.time_index]
        return None


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
    dose_statuses_today = serializers.SerializerMethodField()
    has_multiple_doses = serializers.SerializerMethodField()
    all_doses_taken_today = serializers.SerializerMethodField()

    class Meta:
        model = FoodSupplementItem
        fields = [
            'id', 'user_id', 'name', 'type', 'description',
            'frequency', 'times_per_week',
            'reminder_enabled', 'reminder_times', 'reminder_days',
            'start_date', 'end_date',
            'last_taken_at', 'is_taken_today',
            'is_archived', 'created_at', 'updated_at',
            'biomarker_impacts', 'recent_logs', 'log_count',
            'dose_statuses_today', 'has_multiple_doses', 'all_doses_taken_today'
        ]
        read_only_fields = ['id', 'user_id', 'created_at', 'updated_at']

    def get_recent_logs(self, obj):
        # Get the 5 most recent logs
        recent = obj.logs.all()[:5]
        return FoodSupplementLogSerializer(recent, many=True).data

    def get_log_count(self, obj):
        return obj.logs.count()

    def get_is_taken_today(self, obj):
        """Check if the item was marked as taken today (for single-dose items)"""
        if not obj.last_taken_at:
            return False
        today = timezone.now().date()
        return obj.last_taken_at.date() == today

    def get_has_multiple_doses(self, obj):
        """Check if item has multiple reminder times (multi-dose)"""
        return bool(obj.reminder_times and len(obj.reminder_times) > 1)

    def get_dose_statuses_today(self, obj):
        """Get today's dose statuses for multi-dose items"""
        if not obj.reminder_times or len(obj.reminder_times) <= 1:
            return []

        try:
            today = timezone.now().date()
            # Get existing statuses for today
            existing_statuses = {
                ds.time_index: ds
                for ds in obj.dose_statuses.filter(date=today)
            }

            # Build response with all dose times
            result = []
            for i, time_str in enumerate(obj.reminder_times):
                if i in existing_statuses:
                    status = existing_statuses[i]
                    result.append({
                        'id': str(status.id),
                        'time_index': i,
                        'time': time_str,
                        'is_taken': status.is_taken,
                        'taken_at': status.taken_at.isoformat() if status.taken_at else None
                    })
                else:
                    result.append({
                        'id': None,
                        'time_index': i,
                        'time': time_str,
                        'is_taken': False,
                        'taken_at': None
                    })
            return result
        except Exception:
            # If dose_statuses table doesn't exist yet (migration pending), return empty list
            return []

    def get_all_doses_taken_today(self, obj):
        """Check if all doses have been taken today (for multi-dose items)"""
        if not obj.reminder_times or len(obj.reminder_times) <= 1:
            # For single-dose items, use the legacy is_taken_today
            return self.get_is_taken_today(obj)

        try:
            today = timezone.now().date()
            taken_count = obj.dose_statuses.filter(date=today, is_taken=True).count()
            return taken_count >= len(obj.reminder_times)
        except Exception:
            # If dose_statuses table doesn't exist yet (migration pending), return False
            return False


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
