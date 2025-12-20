import os
import stripe
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from rest_framework.views import APIView
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
if not stripe.api_key:
    raise RuntimeError('STRIPE_SECRET_KEY environment variable is required')


class CreateCheckoutSessionView(APIView):
    """
    Create a Stripe Checkout Session for subscription.
    POST /api/subscriptions/checkout/
    
    Body:
    {
        "plan": "monthly" or "yearly",
        "success_url": "https://your-app.com/success",
        "cancel_url": "https://your-app.com/cancel"
    }
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            user_id = request.user.user_id
            plan = request.data.get('plan', 'yearly')
            
            # Get Stripe product/price IDs from environment variables
            # You'll need to set these based on your Stripe products
            if plan == 'yearly':
                price_id = os.environ.get('STRIPE_YEARLY_PRICE_ID')
            else:  # monthly
                price_id = os.environ.get('STRIPE_MONTHLY_PRICE_ID')
            
            if not price_id:
                return Response(
                    {'error': f'Stripe price ID for {plan} plan not configured'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            # Get success and cancel URLs from request or use defaults
            success_url = request.data.get('success_url', 'lumo://subscription-success')
            cancel_url = request.data.get('cancel_url', 'lumo://subscription-cancel')
            
            # Create Stripe Checkout Session with 3-day free trial
            checkout_session = stripe.checkout.Session.create(
                customer_email=request.data.get('email'),  # Optional: pre-fill email
                payment_method_types=['card'],
                line_items=[
                    {
                        'price': price_id,
                        'quantity': 1,
                    },
                ],
                mode='subscription',
                subscription_data={
                    'trial_period_days': 3,  # 3-day free trial
                },
                success_url=success_url + '?session_id={CHECKOUT_SESSION_ID}',
                cancel_url=cancel_url,
                client_reference_id=user_id,  # Store user ID for webhook processing
                metadata={
                    'user_id': user_id,
                    'plan': plan,
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


class GetSubscriptionStatusView(APIView):
    """
    Get the current subscription status for the user.
    GET /api/subscriptions/status/
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        try:
            user_id = request.user.user_id
            
            # Query Supabase to get subscription status
            supabase = get_supabase_client()
            
            # Check if user has active subscription in your database
            # Count subscriptions with status = 'active' or 'trialing' (trial users should have access)
            response = supabase.table('subscriptions').select('id').eq('user_id', user_id).in_('status', ['active', 'trialing']).execute()
            
            # Explicitly check for active/trialing subscriptions - only return true if we find at least one
            has_active_subscription = bool(response.data and len(response.data) > 0)
            
            return Response({
                'has_active_subscription': has_active_subscription,
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response(
                {'error': f'Error getting subscription status: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@method_decorator(csrf_exempt, name='dispatch')
class StripeWebhookView(APIView):
    """
    Handle Stripe webhook events.
    POST /api/subscriptions/webhook/
    
    This endpoint should be called by Stripe when subscription events occur.
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
        
        # Handle the event
        supabase = get_supabase_client()
        
        if event['type'] == 'checkout.session.completed':
            session = event['data']['object']
            user_id = session.get('client_reference_id')
            customer_id = session.get('customer')
            payment_status = session.get('payment_status')
            subscription_id = session.get('subscription')
            
            # Only activate subscription if payment was successful
            if payment_status == 'paid' and subscription_id:
                # Cancel any existing active or trialing subscriptions for this user
                # This ensures each user can only have one subscription (active or trialing)
                existing_active = supabase.table('subscriptions').select('stripe_subscription_id').eq('user_id', user_id).in_('status', ['active', 'trialing']).execute()
                
                if existing_active.data:
                    for existing_sub in existing_active.data:
                        existing_subscription_id = existing_sub.get('stripe_subscription_id')
                        if existing_subscription_id and existing_subscription_id != subscription_id:
                            try:
                                # Cancel the existing subscription in Stripe
                                stripe.Subscription.delete(existing_subscription_id)
                                # Update status in database
                                supabase.table('subscriptions').update({
                                    'status': 'cancelled',
                                }).eq('stripe_subscription_id', existing_subscription_id).execute()
                            except Exception as cancel_error:
                                # If cancellation fails, still try to update database status
                                print(f'Warning: Failed to cancel existing subscription {existing_subscription_id}: {str(cancel_error)}')
                                supabase.table('subscriptions').update({
                                    'status': 'cancelled',
                                }).eq('stripe_subscription_id', existing_subscription_id).execute()
                
                # Get the subscription object to check its status (trial vs active)
                subscription_obj = stripe.Subscription.retrieve(subscription_id)
                subscription_status_from_stripe = subscription_obj.status
                
                # Map Stripe subscription status to our status
                status_map = {
                    'active': 'active',
                    'trialing': 'trialing',
                    'past_due': 'past_due',
                    'canceled': 'cancelled',
                    'unpaid': 'unpaid',
                }
                mapped_status = status_map.get(subscription_status_from_stripe, 'active')
                
                # Now create/update the new subscription
                # Use stripe_subscription_id for conflict resolution since it's unique
                supabase.table('subscriptions').upsert({
                    'user_id': user_id,
                    'stripe_customer_id': customer_id,
                    'stripe_subscription_id': subscription_id,
                    'status': mapped_status,  # Will be 'trialing' if in trial, 'active' otherwise
                    'plan': session.get('metadata', {}).get('plan', 'yearly'),
                }, on_conflict='stripe_subscription_id').execute()
            # If payment failed, we don't create/update subscription
            # The user will need to retry checkout
            
        elif event['type'] == 'customer.subscription.updated':
            subscription = event['data']['object']
            subscription_id = subscription.get('id')
            subscription_status = subscription.get('status')
            customer_id = subscription.get('customer')
            
            # Map Stripe subscription status to our status
            status_map = {
                'active': 'active',
                'past_due': 'past_due',
                'canceled': 'cancelled',
                'unpaid': 'unpaid',
                'trialing': 'trialing',
            }
            
            mapped_status = status_map.get(subscription_status, 'active')
            
            # Update subscription status in Supabase
            supabase.table('subscriptions').update({
                'status': mapped_status,
            }).eq('stripe_subscription_id', subscription_id).execute()
            
        elif event['type'] == 'customer.subscription.deleted':
            subscription = event['data']['object']
            subscription_id = subscription.get('id')
            customer_id = subscription.get('customer')
            
            # Update subscription status in Supabase
            supabase.table('subscriptions').update({
                'status': 'cancelled',
            }).eq('stripe_subscription_id', subscription_id).execute()
            
        elif event['type'] == 'invoice.payment_failed':
            invoice = event['data']['object']
            subscription_id = invoice.get('subscription')
            customer_id = invoice.get('customer')
            
            # Update subscription status to past_due or unpaid
            if subscription_id:
                supabase.table('subscriptions').update({
                    'status': 'past_due',
                }).eq('stripe_subscription_id', subscription_id).execute()
            
        elif event['type'] == 'invoice.payment_succeeded':
            invoice = event['data']['object']
            subscription_id = invoice.get('subscription')
            
            # Reactivate subscription if it was past_due or unpaid
            if subscription_id:
                supabase.table('subscriptions').update({
                    'status': 'active',
                }).eq('stripe_subscription_id', subscription_id).execute()
        
        return Response({'status': 'success'}, status=status.HTTP_200_OK)


class CreatePortalSessionView(APIView):
    """
    Create a Stripe Customer Portal Session for managing subscription.
    POST /api/subscriptions/portal/
    
    This allows users to manage their subscription, update payment methods, view invoices, etc.
    """
    authentication_classes = [SupabaseAuthentication]
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            user_id = request.user.user_id
            
            # Get the user's Stripe customer ID from Supabase
            supabase = get_supabase_client()
            subscription_response = supabase.table('subscriptions').select('stripe_customer_id').eq('user_id', user_id).execute()
            
            if not subscription_response.data or not subscription_response.data[0].get('stripe_customer_id'):
                return Response(
                    {'error': 'No active subscription found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            customer_id = subscription_response.data[0]['stripe_customer_id']
            
            # Get return URL from request or use default
            return_url = request.data.get('return_url', 'lumo://settings')
            
            # Create Stripe Customer Portal Session
            portal_session = stripe.billing_portal.Session.create(
                customer=customer_id,
                return_url=return_url,
            )
            
            return Response({
                'url': portal_session.url,
            }, status=status.HTTP_200_OK)
            
        except stripe.error.StripeError as e:
            return Response(
                {'error': f'Stripe error: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {'error': f'Error creating portal session: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
