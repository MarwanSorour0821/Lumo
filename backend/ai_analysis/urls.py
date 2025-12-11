from django.urls import path
from .views import AnalyzeBloodTestView, HealthCheckView

urlpatterns = [
    path('analyze/', AnalyzeBloodTestView.as_view(), name='analyze-blood-test'),
    path('health/', HealthCheckView.as_view(), name='health-check'),
]
