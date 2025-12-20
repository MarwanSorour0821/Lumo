/**
 * Subscription API functions for Stripe checkout
 */

import { makeRedirectUri } from 'expo-auth-session';
import * as Linking from 'expo-linking';
import Constants from 'expo-constants';
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
 * Get the appropriate redirect URL for the current environment
 * - In Expo Go: exp://192.168.x.x:8081/--/path
 * - In standalone app: Lumo://path
 */
function getSubscriptionRedirectUrl(path: string): string {
  // Check if running in Expo Go
  const isExpoGo = Constants.appOwnership === 'expo';
  
  if (isExpoGo) {
    // Use Linking.createURL which handles Expo Go correctly
    const url = Linking.createURL(path);
    console.log(`Subscription redirect URL (Expo Go): ${url}`);
    return url;
  }
  
  // For standalone builds, use the custom scheme
  // Note: scheme is 'Lumo' (capital L) in app.json
  const url = makeRedirectUri({
    scheme: 'Lumo',
    path: path,
  });
  console.log(`Subscription redirect URL (Standalone): ${url}`);
  return url;
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

    // Get redirect URLs for the current environment
    const defaultSuccessUrl = getSubscriptionRedirectUrl('subscription-success');
    const defaultCancelUrl = getSubscriptionRedirectUrl('subscription-cancel');
    
    // Log the URLs for debugging
    console.log('Subscription callback URLs:', { defaultSuccessUrl, defaultCancelUrl });

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

/**
 * Create a Stripe Customer Portal Session for managing subscription
 */
export async function createPortalSession(
  returnUrl?: string
): Promise<{ url: string; error?: string }> {
  try {
    // Get current session to get auth token
    const { data: sessionData, error: sessionError } = await supabase?.auth.getSession();
    
    if (sessionError || !sessionData?.session) {
      return {
        url: '',
        error: 'Not authenticated. Please sign in first.',
      };
    }

    const token = sessionData.session.access_token;
    const defaultReturnUrl = getSubscriptionRedirectUrl('settings');
    
    console.log('Portal return URL:', defaultReturnUrl);

    const response = await fetch(`${API_BASE_URL}/api/subscriptions/portal/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        return_url: returnUrl || defaultReturnUrl,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return {
        url: '',
        error: data.error || 'Failed to create portal session',
      };
    }

    return {
      url: data.url,
    };
  } catch (error: any) {
    return {
      url: '',
      error: error.message || 'Network error',
    };
  }
}

