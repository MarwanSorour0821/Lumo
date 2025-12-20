from django.urls import path
from . import views

app_name = 'auth'

urlpatterns = [
    path('google/', views.google_oauth_initiate, name='google_oauth_initiate'),
    path('google/callback/', views.google_oauth_callback, name='google_oauth_callback'),
]


