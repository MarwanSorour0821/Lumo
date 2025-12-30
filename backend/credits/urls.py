from django.urls import path
from . import views

urlpatterns = [
    path('', views.GetCreditsView.as_view(), name='get_credits'),
    path('deduct/', views.DeductCreditView.as_view(), name='deduct_credit'),
    path('checkout/', views.CreateCreditCheckoutView.as_view(), name='create_credit_checkout'),
    path('webhook/', views.CreditWebhookView.as_view(), name='credit_webhook'),
]
