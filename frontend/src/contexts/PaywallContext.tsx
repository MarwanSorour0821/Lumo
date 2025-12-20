import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getSubscriptionStatus } from '../lib/subscriptions';

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
}

type PaywallTrigger = 
  | 'first_analysis_complete'
  | 'second_upload_attempt'
  | 'trend_view_attempt'
  | 'history_attempt'
  | 'compare_attempt'
  | 'export_attempt'
  | 'score_breakdown_attempt'
  | 'session_count'
  | 'time_based';

const PAYWALL_STORAGE_KEYS = {
  DISMISSED_AT: '@paywall_dismissed_at',
  USAGE_EVENTS: '@paywall_usage_events',
  FIRST_ANALYSIS_COMPLETE: '@paywall_first_analysis_complete',
  SESSION_COUNT: '@paywall_session_count',
};

const COOLDOWN_HOURS = 48; // 48-72 hours as recommended
const MIN_USAGE_EVENTS = 3; // Minimum usage events before re-show
const MIN_SESSION_TIME_MS = 3 * 60 * 1000; // 3 minutes

export const PaywallContext = createContext<PaywallContextType | undefined>(undefined);

export function PaywallProvider({ children }: { children: React.ReactNode }) {
  const [hasActiveSubscription, setHasActiveSubscription] = useState(false);
  const [firstAnalysisComplete, setFirstAnalysisComplete] = useState(false);

  // Load initial state
  useEffect(() => {
    const loadState = async () => {
      try {
        const firstAnalysis = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.FIRST_ANALYSIS_COMPLETE);
        setFirstAnalysisComplete(firstAnalysis === 'true');
        
        // Load subscription status from backend
        const statusResponse = await getSubscriptionStatus();
        // Explicitly set to false if there's an error or if the value is falsy
        if (statusResponse.error) {
          console.log('Error fetching subscription status:', statusResponse.error);
          setHasActiveSubscription(false);
        } else {
          // Explicitly ensure boolean value
          setHasActiveSubscription(statusResponse.has_active_subscription === true);
        }
      } catch (error) {
        console.error('Error loading paywall state:', error);
        setHasActiveSubscription(false);
      }
    };
    loadState();
  }, []);

  // Function to refresh subscription status
  const refreshSubscriptionStatus = useCallback(async () => {
    try {
      const statusResponse = await getSubscriptionStatus();
      // Explicitly set to false if there's an error or if the value is falsy
      if (statusResponse.error) {
        console.log('Error refreshing subscription status:', statusResponse.error);
        setHasActiveSubscription(false);
      } else {
        // Explicitly ensure boolean value
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

    try {
      const dismissedAt = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.DISMISSED_AT);
      const usageEventsStr = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.USAGE_EVENTS);
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
  }, [hasActiveSubscription]);

  // Get remaining cooldown time in hours
  const getPaywallCooldownRemaining = useCallback(async (): Promise<number> => {
    try {
      const dismissedAt = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.DISMISSED_AT);
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
  }, []);

  // Check if paywall should show for a specific trigger
  const shouldShowPaywall = useCallback((trigger: PaywallTrigger): boolean => {
    // Never show if user has active subscription
    if (hasActiveSubscription) {
      return false;
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
    try {
      await AsyncStorage.setItem(PAYWALL_STORAGE_KEYS.DISMISSED_AT, Date.now().toString());
      // Reset usage events counter when dismissed
      await AsyncStorage.setItem(PAYWALL_STORAGE_KEYS.USAGE_EVENTS, '0');
    } catch (error) {
      console.error('Error dismissing paywall:', error);
    }
  }, []);

  // Track usage event
  const trackUsageEvent = useCallback(async () => {
    try {
      const usageEventsStr = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.USAGE_EVENTS);
      const currentEvents = usageEventsStr ? parseInt(usageEventsStr, 10) : 0;
      await AsyncStorage.setItem(PAYWALL_STORAGE_KEYS.USAGE_EVENTS, (currentEvents + 1).toString());
    } catch (error) {
      console.error('Error tracking usage event:', error);
    }
  }, []);

  // Mark first analysis as complete
  const markFirstAnalysisComplete = useCallback(async () => {
    try {
      await AsyncStorage.setItem(PAYWALL_STORAGE_KEYS.FIRST_ANALYSIS_COMPLETE, 'true');
      setFirstAnalysisComplete(true);
    } catch (error) {
      console.error('Error marking first analysis complete:', error);
    }
  }, []);

  // Check if first analysis is complete
  const isFirstAnalysisComplete = useCallback(async (): Promise<boolean> => {
    try {
      const value = await AsyncStorage.getItem(PAYWALL_STORAGE_KEYS.FIRST_ANALYSIS_COMPLETE);
      return value === 'true';
    } catch (error) {
      console.error('Error checking first analysis:', error);
      return false;
    }
  }, []);

  // Check and show paywall for a specific trigger
  const checkAndShowPaywall = useCallback(async (trigger: PaywallTrigger, navigation: any) => {
    // Never show if user has active subscription
    if (hasActiveSubscription) {
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
  }, [hasActiveSubscription, shouldShowPaywall, canShowPaywall, isFirstAnalysisComplete, markFirstAnalysisComplete]);

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

