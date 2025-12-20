/**
 * Subscription API functions for Stripe checkout
 */

import { supabase } from './supabase';

// API base URL - adjust based on your environment
const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8000';

// Stripe Publishable Key (optional - not needed for server-side checkout, but useful for future client-side features)
export const STRIPE_PUBLISHABLE_KEY = process.env.EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY || '';

export interface CreateCheckoutSessionResponse {
  checkout_url: string;
  session_id: string;
  error?: string;
}

export interface SubscriptionStatusResponse {
  has_active_subscription: boolean;
  error?: string;
}

/**
 * Create a Stripe Checkout Session for subscription
 */
export async function createCheckoutSession(
  plan: 'monthly' | 'yearly',
  successUrl?: string,
  cancelUrl?: string
): Promise<CreateCheckoutSessionResponse> {
  try {
    // Get current session to get auth token
    const { data: sessionData, error: sessionError } = await supabase?.auth.getSession();
    
    if (sessionError || !sessionData?.session) {
      return {
        checkout_url: '',
        session_id: '',
        error: 'Not authenticated. Please sign in first.',
      };
    }

    const token = sessionData.session.access_token;
    const userEmail = sessionData.session.user.email;

    // Default URLs for deep linking
    const defaultSuccessUrl = 'lumo://subscription-success';
    const defaultCancelUrl = 'lumo://subscription-cancel';

    const response = await fetch(`${API_BASE_URL}/api/subscriptions/checkout/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        plan: plan,
        email: userEmail,
        success_url: successUrl || defaultSuccessUrl,
        cancel_url: cancelUrl || defaultCancelUrl,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return {
        checkout_url: '',
        session_id: '',
        error: data.error || 'Failed to create checkout session',
      };
    }

    return {
      checkout_url: data.checkout_url,
      session_id: data.session_id,
    };
  } catch (error: any) {
    return {
      checkout_url: '',
      session_id: '',
      error: error.message || 'Network error',
    };
  }
}

/**
 * Get subscription status for the current user
 */
export async function getSubscriptionStatus(): Promise<SubscriptionStatusResponse> {
  try {
    // Get current session to get auth token
    const { data: sessionData, error: sessionError } = await supabase?.auth.getSession();
    
    if (sessionError || !sessionData?.session) {
      return {
        has_active_subscription: false,
        error: 'Not authenticated',
      };
    }

    const token = sessionData.session.access_token;

    const response = await fetch(`${API_BASE_URL}/api/subscriptions/status/`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    });

    const data = await response.json();

    if (!response.ok) {
      return {
        has_active_subscription: false,
        error: data.error || 'Failed to get subscription status',
      };
    }

    return {
      has_active_subscription: data.has_active_subscription || false,
    };
  } catch (error: any) {
    return {
      has_active_subscription: false,
      error: error.message || 'Network error',
    };
  }
}

