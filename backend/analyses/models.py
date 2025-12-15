import uuid
from django.db import models


class Analysis(models.Model):
    """
    Model representing a blood test analysis.
    Maps to the 'analyses' table in Supabase PostgreSQL.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id = models.UUIDField(db_index=True)
    parsed_data = models.JSONField()
    analysis = models.JSONField()
    title = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analyses'
        ordering = ['-created_at']
        verbose_name = 'Analysis'
        verbose_name_plural = 'Analyses'

    def __str__(self):
        return f"Analysis {self.id} for user {self.user_id}"

    def generate_title(self):
        """Generate a title from the parsed data if not set."""
        if self.title:
            return self.title
        
        # Try to get test date from parsed data
        try:
            patient_info = self.parsed_data.get('patient_info', {})
            test_date = patient_info.get('test_date')
            if test_date:
                return f"Blood Test - {test_date}"
        except (AttributeError, TypeError):
            pass
        
        return f"Blood Test Analysis"
