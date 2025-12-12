from rest_framework import serializers
from .models import Analysis


class AnalysisSerializer(serializers.ModelSerializer):
    """Serializer for full analysis details."""
    title = serializers.SerializerMethodField()

    class Meta:
        model = Analysis
        fields = ['id', 'user_id', 'parsed_data', 'analysis', 'title', 'created_at', 'updated_at']
        read_only_fields = ['id', 'user_id', 'created_at', 'updated_at']

    def get_title(self, obj):
        return obj.generate_title()


class AnalysisListSerializer(serializers.ModelSerializer):
    """Serializer for analysis list (lighter version)."""
    title = serializers.SerializerMethodField()
    markers_count = serializers.SerializerMethodField()
    summary = serializers.SerializerMethodField()

    class Meta:
        model = Analysis
        fields = ['id', 'title', 'markers_count', 'summary', 'created_at']

    def get_title(self, obj):
        return obj.generate_title()

    def get_markers_count(self, obj):
        """Get the number of test markers in this analysis."""
        try:
            test_results = obj.parsed_data.get('test_results', [])
            return len(test_results)
        except (AttributeError, TypeError):
            return 0

    def get_summary(self, obj):
        """Get a brief summary of the analysis status."""
        try:
            test_results = obj.parsed_data.get('test_results', [])
            abnormal_count = sum(
                1 for r in test_results 
                if r.get('status') in ['high', 'low']
            )
            total = len(test_results)
            if abnormal_count == 0:
                return "All markers normal"
            return f"{abnormal_count} of {total} markers abnormal"
        except (AttributeError, TypeError):
            return "Analysis complete"


class CreateAnalysisSerializer(serializers.Serializer):
    """Serializer for creating a new analysis."""
    parsed_data = serializers.JSONField()
    analysis = serializers.CharField()
    title = serializers.CharField(required=False, allow_blank=True, allow_null=True)
