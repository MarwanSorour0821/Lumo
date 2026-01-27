from django.urls import path
from .views import SupplementScheduleView

urlpatterns = [
    path('schedule/', SupplementScheduleView.as_view(), name='supplement-schedule'),
]
