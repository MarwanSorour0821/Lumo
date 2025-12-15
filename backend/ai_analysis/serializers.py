from rest_framework import serializers


class BloodTestUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
    

class BloodTestAnalysisSerializer(serializers.Serializer):
    parsed_data = serializers.JSONField()
    analysis = serializers.CharField()
    structured_analysis = serializers.JSONField(required=False, allow_null=True)
    created_at = serializers.DateTimeField()
