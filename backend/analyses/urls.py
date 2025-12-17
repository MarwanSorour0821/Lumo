from django.urls import path
from .views import AnalysisListCreateView, AnalysisDetailView, DeleteAccountView

urlpatterns = [
    path('', AnalysisListCreateView.as_view(), name='analysis-list-create'),
    path('<uuid:analysis_id>/', AnalysisDetailView.as_view(), name='analysis-detail'),
    path('delete-account/', DeleteAccountView.as_view(), name='delete-account'),
]
