import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getSubscriptionStatus } from '../lib/subscriptions';
import { supabase } from '../lib/supabase';

interface PaywallContextType {
  hasActiveSubscription: boolean;
  setHasActiveSubscription: (value: boolean) => void;
  shouldShowPaywall: (trigger: PaywallTrigger) => boolean;
  dismissPaywall: () => Promise<void>;
  trackUsageEvent: () => Promise<void>;
  canShowPaywall: () => Promise<boolean>;
  getPaywallCooldownRemaining: () => Promise<number>;
  markFirstAnalysisComplete: () => Promise<void>;
  isFirstAnalysisComplete: () => Promise<boolean>;
  checkAndShowPaywall: (trigger: PaywallTrigger, navigation: any) => Promise<void>;
  refreshSubscriptionStatus: () => Promise<void>;
  showPaywallForOnboarding: (navigation: any) => Promise<void>;
  clearUserPaywallData: () => Promise<void>;
  initializeForUser: (userId: string) => Promise<void>;
}

export type PaywallTrigger = 
  | 'onboarding_complete'
  | 'first_analysis_complete'
  | 'second_upload_attempt'
  | 'trend_view_attempt'
  | 'history_attempt'
  | 'compare_attempt'
  | 'export_attempt'
  | 'score_breakdown_attempt'
  | 'session_count'
  | 'time_based';

// Base keys - will be prefixed with user ID
const PAYWALL_STORAGE_KEY_BASE = {
  DISMISSED_AT: 'paywall_dismissed_at',
  USAGE_EVENTS: 'paywall_usage_events',
  FIRST_ANALYSIS_COMPLETE: 'paywall_first_analysis_complete',
  SESSION_COUNT: 'paywall_session_count',
  ONBOARDING_PAYWALL_SHOWN: 'paywall_onboarding_shown',
};

const COOLDOWN_HOURS = 48; // 48-72 hours as recommended
const MIN_USAGE_EVENTS = 3; // Minimum usage events before re-show

export const PaywallContext = createContext<PaywallContextType | undefined>(undefined);

export function PaywallProvider({ children }: { children: React.ReactNode }) {
  const [hasActiveSubscription, setHasActiveSubscription] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const isInitializing = useRef(false);

  // Generate user-specific storage key
  const getUserKey = useCallback((baseKey: string): string => {
    if (!currentUserId) {
      // Fallback to legacy key if no user ID (shouldn't happen in normal flow)
      console.warn('No user ID available for paywall storage key');
      return `@${baseKey}`;
    }
    return `@${currentUserId}_${baseKey}`;
  }, [currentUserId]);

  // Initialize for a specific user
  const initializeForUser = useCallback(async (userId: string) => {
    if (isInitializing.current) return;
    isInitializing.current = true;
    
    try {
      console.log('PaywallContext: Initializing for user:', userId);
      setCurrentUserId(userId);
      
      // Load subscription status from backend
      const statusResponse = await getSubscriptionStatus();
      if (statusResponse.error) {
        console.log('Error fetching subscription status:', statusResponse.error);
        setHasActiveSubscription(false);
      } else {
        setHasActiveSubscription(statusResponse.has_active_subscription === true);
      }
    } catch (error) {
      console.error('Error initializing paywall for user:', error);
      setHasActiveSubscription(false);
    } finally {
      isInitializing.current = false;
    }
  }, []);

  // Clear all paywall data for current user (call on logout)
  const clearUserPaywallData = useCallback(async () => {
    if (!currentUserId) return;
    
    try {
      const keys = Object.values(PAYWALL_STORAGE_KEY_BASE).map(key => getUserKey(key));
      await AsyncStorage.multiRemove(keys);
      console.log('PaywallContext: Cleared paywall data for user:', currentUserId);
    } catch (error) {
      console.error('Error clearing paywall data:', error);
    }
  }, [currentUserId, getUserKey]);

  // Load initial state and listen for auth changes
  useEffect(() => {
    const loadState = async () => {
      try {
        // Get current user
        const { data: { session } } = await supabase?.auth.getSession() || { data: { session: null } };
        
        if (session?.user?.id) {
          await initializeForUser(session.user.id);
        } else {
          // No user logged in - reset state
          setCurrentUserId(null);
          setHasActiveSubscription(false);
        }
      } catch (error) {
        console.error('Error loading paywall state:', error);
        setHasActiveSubscription(false);
      }
    };
    
    loadState();

    // Listen for auth state changes
    const { data: { subscription } } = supabase?.auth.onAuthStateChange(async (event, session) => {
      console.log('PaywallContext: Auth state changed:', event);
      
      if (event === 'SIGNED_IN' && session?.user?.id) {
        await initializeForUser(session.user.id);
      } else if (event === 'SIGNED_OUT') {
        setCurrentUserId(null);
        setHasActiveSubscription(false);
      }
    }) || { data: { subscription: null } };

    return () => {
      subscription?.unsubscribe();
    };
  }, [initializeForUser]);

  // Function to refresh subscription status
  const refreshSubscriptionStatus = useCallback(async () => {
    try {
      const statusResponse = await getSubscriptionStatus();
      if (statusResponse.error) {
        console.log('Error refreshing subscription status:', statusResponse.error);
        setHasActiveSubscription(false);
      } else {
        setHasActiveSubscription(statusResponse.has_active_subscription === true);
      }
    } catch (error) {
      console.error('Error refreshing subscription status:', error);
      setHasActiveSubscription(false);
    }
  }, []);

  // Check if paywall can be shown (cooldown logic)
  const canShowPaywall = useCallback(async (): Promise<boolean> => {
    // Never show if user has active subscription
    if (hasActiveSubscription) {
      return false;
    }

    if (!currentUserId) {
      return false;
    }

    try {
      const dismissedAt = await AsyncStorage.getItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.DISMISSED_AT));
      const usageEventsStr = await AsyncStorage.getItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.USAGE_EVENTS));
      const usageEvents = usageEventsStr ? parseInt(usageEventsStr, 10) : 0;

      // If never dismissed, can show
      if (!dismissedAt) {
        return true;
      }

      const dismissedTime = parseInt(dismissedAt, 10);
      const now = Date.now();
      const hoursSinceDismissal = (now - dismissedTime) / (1000 * 60 * 60);

      // Can show if cooldown period passed OR enough usage events occurred
      return hoursSinceDismissal >= COOLDOWN_HOURS || usageEvents >= MIN_USAGE_EVENTS;
    } catch (error) {
      console.error('Error checking paywall cooldown:', error);
      return false;
    }
  }, [hasActiveSubscription, currentUserId, getUserKey]);

  // Get remaining cooldown time in hours
  const getPaywallCooldownRemaining = useCallback(async (): Promise<number> => {
    if (!currentUserId) return 0;

    try {
      const dismissedAt = await AsyncStorage.getItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.DISMISSED_AT));
      if (!dismissedAt) {
        return 0;
      }

      const dismissedTime = parseInt(dismissedAt, 10);
      const now = Date.now();
      const hoursSinceDismissal = (now - dismissedTime) / (1000 * 60 * 60);
      const remaining = COOLDOWN_HOURS - hoursSinceDismissal;

      return Math.max(0, remaining);
    } catch (error) {
      console.error('Error getting cooldown remaining:', error);
      return 0;
    }
  }, [currentUserId, getUserKey]);

  // Check if paywall should show for a specific trigger
  const shouldShowPaywall = useCallback((trigger: PaywallTrigger): boolean => {
    // Never show if user has active subscription
    if (hasActiveSubscription) {
      return false;
    }

    // onboarding_complete is a special case - ALWAYS show
    if (trigger === 'onboarding_complete') {
      return true;
    }

    // Tier A triggers - always show if cooldown allows
    const tierATriggers: PaywallTrigger[] = [
      'first_analysis_complete',
      'second_upload_attempt',
      'trend_view_attempt',
      'history_attempt',
      'compare_attempt',
      'export_attempt',
      'score_breakdown_attempt',
    ];

    if (tierATriggers.includes(trigger)) {
      return true; // Will be checked against cooldown in canShowPaywall
    }

    // Tier B triggers - less aggressive
    const tierBTriggers: PaywallTrigger[] = ['session_count', 'time_based'];
    if (tierBTriggers.includes(trigger)) {
      return true; // Will be checked against cooldown in canShowPaywall
    }

    return false;
  }, [hasActiveSubscription]);

  // Dismiss paywall (when user presses X)
  const dismissPaywall = useCallback(async () => {
    if (!currentUserId) return;

    try {
      await AsyncStorage.setItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.DISMISSED_AT), Date.now().toString());
      // Reset usage events counter when dismissed
      await AsyncStorage.setItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.USAGE_EVENTS), '0');
    } catch (error) {
      console.error('Error dismissing paywall:', error);
    }
  }, [currentUserId, getUserKey]);

  // Track usage event
  const trackUsageEvent = useCallback(async () => {
    if (!currentUserId) return;

    try {
      const usageEventsStr = await AsyncStorage.getItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.USAGE_EVENTS));
      const currentEvents = usageEventsStr ? parseInt(usageEventsStr, 10) : 0;
      await AsyncStorage.setItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.USAGE_EVENTS), (currentEvents + 1).toString());
    } catch (error) {
      console.error('Error tracking usage event:', error);
    }
  }, [currentUserId, getUserKey]);

  // Mark first analysis as complete
  const markFirstAnalysisComplete = useCallback(async () => {
    if (!currentUserId) return;

    try {
      await AsyncStorage.setItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.FIRST_ANALYSIS_COMPLETE), 'true');
    } catch (error) {
      console.error('Error marking first analysis complete:', error);
    }
  }, [currentUserId, getUserKey]);

  // Check if first analysis is complete
  const isFirstAnalysisComplete = useCallback(async (): Promise<boolean> => {
    if (!currentUserId) return false;

    try {
      const value = await AsyncStorage.getItem(getUserKey(PAYWALL_STORAGE_KEY_BASE.FIRST_ANALYSIS_COMPLETE));
      return value === 'true';
    } catch (error) {
      console.error('Error checking first analysis:', error);
      return false;
    }
  }, [currentUserId, getUserKey]);

  // Show paywall specifically for onboarding completion
  // This ALWAYS shows the paywall for new users, ignoring cooldowns
  const showPaywallForOnboarding = useCallback(async (navigation: any) => {
    try {
      // Get user ID directly from Supabase to avoid race conditions with state
      const { data: { session } } = await supabase?.auth.getSession() || { data: { session: null } };
      const userId = session?.user?.id;
      
      if (!userId) {
        console.log('PaywallContext: No user ID from session, not showing onboarding paywall');
        return;
      }

      console.log('PaywallContext: showPaywallForOnboarding for user:', userId);

      // Refresh subscription status first
      await refreshSubscriptionStatus();
      
      // Re-check subscription after refresh
      const statusResponse = await getSubscriptionStatus();
      if (statusResponse.has_active_subscription === true) {
        console.log('PaywallContext: User has active subscription, not showing onboarding paywall');
        return;
      }

      // Generate user-specific key
      const userKey = `@${userId}_${PAYWALL_STORAGE_KEY_BASE.ONBOARDING_PAYWALL_SHOWN}`;

      // Check if we've already shown the onboarding paywall for this user
      const onboardingPaywallShown = await AsyncStorage.getItem(userKey);

      if (onboardingPaywallShown === 'true') {
        console.log('PaywallContext: Onboarding paywall already shown for this user');
        return;
      }

      // Mark that we're showing the onboarding paywall
      await AsyncStorage.setItem(userKey, 'true');

      console.log('PaywallContext: Showing onboarding paywall');
      
      // Navigate to paywall after a short delay to ensure previous screen is mounted
      setTimeout(() => {
        navigation.navigate('PaywallMain');
      }, 500);
    } catch (error) {
      console.error('Error in showPaywallForOnboarding:', error);
    }
  }, [refreshSubscriptionStatus]);

  // Check and show paywall for a specific trigger (for non-onboarding triggers)
  const checkAndShowPaywall = useCallback(async (trigger: PaywallTrigger, navigation: any) => {
    // Never show if user has active subscription
    if (hasActiveSubscription) {
      return;
    }

    // For onboarding_complete, use the dedicated function
    if (trigger === 'onboarding_complete') {
      await showPaywallForOnboarding(navigation);
      return;
    }

    // Check if trigger should show paywall
    if (!shouldShowPaywall(trigger)) {
      return;
    }

    // Check cooldown
    const canShow = await canShowPaywall();
    if (!canShow) {
      return;
    }

    // For first analysis trigger, check if it's actually the first
    if (trigger === 'first_analysis_complete') {
      const isComplete = await isFirstAnalysisComplete();
      if (!isComplete) {
        // Mark as complete first
        await markFirstAnalysisComplete();
      } else {
        // Not the first analysis, use second_upload_attempt trigger instead
        return;
      }
    }

    // Navigate to paywall
    navigation.navigate('PaywallMain');
  }, [hasActiveSubscription, shouldShowPaywall, canShowPaywall, isFirstAnalysisComplete, markFirstAnalysisComplete, showPaywallForOnboarding]);

  const value: PaywallContextType = {
    hasActiveSubscription,
    setHasActiveSubscription,
    shouldShowPaywall,
    dismissPaywall,
    trackUsageEvent,
    canShowPaywall,
    getPaywallCooldownRemaining,
    markFirstAnalysisComplete,
    isFirstAnalysisComplete,
    checkAndShowPaywall,
    refreshSubscriptionStatus,
    showPaywallForOnboarding,
    clearUserPaywallData,
    initializeForUser,
  };

  return <PaywallContext.Provider value={value}>{children}</PaywallContext.Provider>;
}

export function usePaywall() {
  const context = useContext(PaywallContext);
  if (context === undefined) {
    throw new Error('usePaywall must be used within a PaywallProvider');
  }
  return context;
}
