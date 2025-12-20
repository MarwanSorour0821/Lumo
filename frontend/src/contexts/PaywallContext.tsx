import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { getSubscriptionStatus } from '../lib/subscriptions';

interface PaywallContextType {
  hasActiveSubscription: boolean;
  setHasActiveSubscription: (value: boolean) => void;
  refreshSubscriptionStatus: () => Promise<void>;
}

export const PaywallContext = createContext<PaywallContextType | undefined>(undefined);

export function PaywallProvider({ children }: { children: React.ReactNode }) {
  const [hasActiveSubscription, setHasActiveSubscription] = useState(false);

  // Load initial state
  useEffect(() => {
    const loadState = async () => {
      try {
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

  const value: PaywallContextType = {
    hasActiveSubscription,
    setHasActiveSubscription,
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

