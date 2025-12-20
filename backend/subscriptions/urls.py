from django.urls import path
from . import views

urlpatterns = [
    path('checkout/', views.CreateCheckoutSessionView.as_view(), name='create_checkout_session'),
    path('status/', views.GetSubscriptionStatusView.as_view(), name='get_subscription_status'),
    path('webhook/', views.StripeWebhookView.as_view(), name='stripe_webhook'),
]

