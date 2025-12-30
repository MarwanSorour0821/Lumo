import os
import stripe
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.utils.decorators import method_decorator
from analyses.authentication import SupabaseAuthentication
from supabase import create_client, Client


def get_supabase_client() -> Client:
    """Get Supabase client instance."""
    url = os.environ.get("SUPABASE_URL") or os.environ.get("SUPABASE_PROJECT_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    
    if not url or not key:
        raise RuntimeError('Supabase credentials are missing.')
    
    return create_client(url, key)


# Initialize Stripe
stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')


# Credit bundle configuration
CREDIT_BUNDLES = {
    '1': {
        'credits': 1,
        'price': 1.99,
        'price_id_env': 'STRIPE_CREDIT_1_PRICE_ID',
    },
    '3': {
        'credits': 3,
        'price': 3.99,
        'price_id_env': 'STRIPE_CREDIT_3_PRICE_ID',
    },
    '5': {
        'credits': 5,
        'price': 5.99,
        'price_id_env': 'STRIPE_CREDIT_5_PRICE_ID',
    },
}


class GetCreditsView(APIView):
    """
    Get the current credit balance for the authenticated user.
    GET /api/credits/
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        try:
            user_id = request.user.user_id
            
            supabase = get_supabase_client()
            
            # Get user's credit balance
            response = supabase.table('users').select('credits').eq('id', user_id).execute()
            
            if response.data and len(response.data) > 0:
                credits = response.data[0].get('credits', 0)
            else:
                credits = 0
            
            return Response({
                'credits': credits,
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response(
                {'error': f'Error getting credits: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DeductCreditView(APIView):
    """
    Deduct a credit from the authenticated user's balance.
    POST /api/credits/deduct/
    
    Returns success: true if credit was deducted, false if insufficient credits.
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            user_id = request.user.user_id
            
            supabase = get_supabase_client()
            
            # Use the deduct_credit database function
            response = supabase.rpc('deduct_credit', {'user_uuid': user_id}).execute()
            
            if response.data is True:
                return Response({
                    'success': True,
                    'message': 'Credit deducted successfully',
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Insufficient credits',
                }, status=status.HTTP_402_PAYMENT_REQUIRED)
            
        except Exception as e:
            return Response(
                {'error': f'Error deducting credit: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class CreateCreditCheckoutView(APIView):
    """
    Create a Stripe Checkout Session for purchasing credits.
    POST /api/credits/checkout/
    
    Body:
    {
        "bundle": "1", "3", or "5" (number of credits)
        "success_url": "lumo://credits-success",
        "cancel_url": "lumo://credits-cancel"
    }
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            if not stripe.api_key:
                return Response(
                    {'error': 'Stripe is not configured'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            user_id = request.user.user_id
            bundle_key = str(request.data.get('bundle', '1'))
            
            if bundle_key not in CREDIT_BUNDLES:
                return Response(
                    {'error': 'Invalid bundle. Choose 1, 3, or 5 credits.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            bundle = CREDIT_BUNDLES[bundle_key]
            price_id = os.environ.get(bundle['price_id_env'])
            
            if not price_id:
                return Response(
                    {'error': f'Stripe price ID for {bundle_key} credits not configured'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            success_url = request.data.get('success_url', 'lumo://credits-success')
            cancel_url = request.data.get('cancel_url', 'lumo://credits-cancel')
            
            # Create Stripe Checkout Session for one-time payment
            checkout_session = stripe.checkout.Session.create(
                customer_email=request.data.get('email'),
                payment_method_types=['card'],
                line_items=[
                    {
                        'price': price_id,
                        'quantity': 1,
                    },
                ],
                mode='payment',  # One-time payment, not subscription
                success_url=success_url + '?session_id={CHECKOUT_SESSION_ID}',
                cancel_url=cancel_url,
                client_reference_id=user_id,
                metadata={
                    'user_id': user_id,
                    'credits': bundle['credits'],
                    'purchase_type': 'credits',
                },
            )
            
            return Response({
                'checkout_url': checkout_session.url,
                'session_id': checkout_session.id,
            }, status=status.HTTP_200_OK)
            
        except stripe.error.StripeError as e:
            return Response(
                {'error': f'Stripe error: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {'error': f'Error creating checkout session: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@method_decorator(csrf_exempt, name='dispatch')
class CreditWebhookView(APIView):
    """
    Handle Stripe webhook events for credit purchases.
    POST /api/credits/webhook/
    
    This endpoint is called by Stripe when payment events occur.
    """
    permission_classes = [AllowAny]
    authentication_classes = []
    
    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
        webhook_secret = os.environ.get('STRIPE_WEBHOOK_SECRET')
        
        if not webhook_secret:
            return Response(
                {'error': 'Webhook secret not configured'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, webhook_secret
            )
        except ValueError:
            return Response(
                {'error': 'Invalid payload'},
                status=status.HTTP_400_BAD_REQUEST
            )
        except stripe.error.SignatureVerificationError:
            return Response(
                {'error': 'Invalid signature'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Handle checkout.session.completed for credit purchases
        if event['type'] == 'checkout.session.completed':
            session = event['data']['object']
            metadata = session.get('metadata', {})
            
            # Only process credit purchases
            if metadata.get('purchase_type') == 'credits':
                user_id = metadata.get('user_id') or session.get('client_reference_id')
                credits_to_add = int(metadata.get('credits', 0))
                payment_status = session.get('payment_status')
                
                if payment_status == 'paid' and user_id and credits_to_add > 0:
                    try:
                        supabase = get_supabase_client()
                        
                        # Add credits using the database function
                        supabase.rpc('add_credits', {
                            'user_uuid': user_id,
                            'credits_to_add': credits_to_add
                        }).execute()
                        
                        # Record the purchase
                        supabase.table('credit_purchases').insert({
                            'user_id': user_id,
                            'credits_purchased': credits_to_add,
                            'amount_paid': session.get('amount_total', 0) / 100,  # Convert from cents
                            'stripe_session_id': session.get('id'),
                            'stripe_payment_intent_id': session.get('payment_intent'),
                        }).execute()
                        
                    except Exception as e:
                        print(f'Error adding credits: {str(e)}')
                        return Response(
                            {'error': f'Error adding credits: {str(e)}'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR
                        )
        
        return Response({'status': 'success'}, status=status.HTTP_200_OK)
