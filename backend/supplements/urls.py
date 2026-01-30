from django.urls import path
from .views import SupplementLookupView

urlpatterns = [
    path('lookup/', SupplementLookupView.as_view(), name='supplement-lookup'),
]
