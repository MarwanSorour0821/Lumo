from django.urls import path
from .views import SupplementScheduleView, SupplementScheduleTestView

urlpatterns = [
    path('schedule/', SupplementScheduleView.as_view(), name='supplement-schedule'),
    path('schedule/test/', SupplementScheduleTestView.as_view(), name='supplement-schedule-test'),
]
