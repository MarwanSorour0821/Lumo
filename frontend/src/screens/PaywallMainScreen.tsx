import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Path, Circle, G } from 'react-native-svg';
import LottieView from 'lottie-react-native';
import * as Haptics from 'expo-haptics';
import * as WebBrowser from 'expo-web-browser';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { usePaywall } from '../contexts/PaywallContext';
import { createCheckoutSession, getSubscriptionStatus } from '../lib/subscriptions';

interface PaywallMainScreenProps {
  navigation: any;
}

// Lottie Animation Component
const AmbulanceAnimation = () => (
  <View style={styles.illustrationContainer}>
    <LottieView
      source={require('../../assets/Ambulance.json')}
      autoPlay
      loop
      style={styles.lottieAnimation}
    />
  </View>
);

// Feature Icons
const AIIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"
        fill={Colors.white}
      />
      <Circle cx="9" cy="9" r="1.5" fill={Colors.white} />
      <Circle cx="15" cy="9" r="1.5" fill={Colors.white} />
      <Path
        d="M12 14c-1.5 0-2.8.8-3.5 2h7c-.7-1.2-2-2-3.5-2z"
        fill={Colors.white}
      />
    </Svg>
  </View>
);

const MagnifyingGlassIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Circle cx="11" cy="11" r="8" stroke={Colors.white} strokeWidth="2" />
      <Path d="m21 21-4.35-4.35" stroke={Colors.white} strokeWidth="2" strokeLinecap="round" />
    </Svg>
  </View>
);

const ChartIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M3 3v18h18"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <Path
        d="M7 16l4-4 4 4 6-6"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
);

const LightbulbIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M9 21h6M12 3a6 6 0 0 1 6 6c0 2.22-1.21 4.15-3 5.19V17a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-2.81C6.21 13.15 5 11.22 5 9a6 6 0 0 1 6-6z"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
);

const features = [
  { icon: <AIIcon />, text: 'AI medical assistant' },
  { icon: <MagnifyingGlassIcon />, text: 'Unlimited blood test analyses' },
  { icon: <ChartIcon />, text: 'Historic comparisons' },
  { icon: <LightbulbIcon />, text: 'Actionable insights on your blood tests' },
];

export function PaywallMainScreen({ navigation }: PaywallMainScreenProps) {
  const [selectedPlan, setSelectedPlan] = useState<'monthly' | 'yearly'>('yearly');
  const [isLoading, setIsLoading] = useState(false);
  const { dismissPaywall, refreshSubscriptionStatus } = usePaywall();

  const handlePlanSelect = (plan: 'monthly' | 'yearly') => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSelectedPlan(plan);
  };

  const handleSubscribe = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsLoading(true);

    try {
      // Create Stripe checkout session
      const result = await createCheckoutSession(selectedPlan);

      if (result.error || !result.checkout_url) {
        Alert.alert(
          'Error',
          result.error || 'Failed to create checkout session. Please try again.'
        );
        setIsLoading(false);
        return;
      }

      // Open Stripe checkout in web browser
      const browserResult = await WebBrowser.openBrowserAsync(result.checkout_url, {
        presentationStyle: WebBrowser.WebBrowserPresentationStyle.FORM_SHEET,
        controlsColor: Colors.primary,
      });

      // Handle different browser result types
      if (browserResult.type === 'cancel') {
        // User explicitly cancelled the checkout
        setIsLoading(false);
        // No alert needed - user intentionally cancelled
        return;
      } else if (browserResult.type === 'dismiss') {
        // Browser was dismissed - could be success or user closed it
        setIsLoading(true);
        // Poll for subscription status with retries
        let attempts = 0;
        const maxAttempts = 10;
        const pollInterval = 1000; // 1 second
        
        const checkSubscription = async () => {
          attempts++;
          const statusResponse = await getSubscriptionStatus();
          
          if (statusResponse.has_active_subscription) {
            setIsLoading(false);
            await refreshSubscriptionStatus();
            Alert.alert('Success', 'Your subscription is now active!', [
              { text: 'OK', onPress: () => navigation.goBack() }
            ]);
            return;
          }
          
          if (attempts < maxAttempts) {
            setTimeout(checkSubscription, pollInterval);
          } else {
            // If after max attempts still no subscription, payment may have failed
            setIsLoading(false);
            Alert.alert(
              'Payment Processing',
              'We couldn\'t confirm your subscription status. Please check your email or try again. If you were charged, contact support.',
              [{ text: 'OK', onPress: () => navigation.goBack() }]
            );
          }
        };
        
        // Start polling after a short delay to allow webhook to process
        setTimeout(checkSubscription, 1500);
      } else {
        // Unknown result type
        setIsLoading(false);
      }
    } catch (error: any) {
      setIsLoading(false);
      Alert.alert(
        'Error',
        error.message || 'Failed to open checkout. Please try again.'
      );
    }
  };

  const handleClose = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    // Dismiss paywall (sets cooldown)
    await dismissPaywall();
    // Navigate back to previous screen
    navigation.goBack();
  };

  return (
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity
              style={styles.closeButton}
              onPress={handleClose}
              activeOpacity={0.7}
            >
              <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M18 6L6 18M6 6l12 12"
                  stroke={Colors.white}
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
            </TouchableOpacity>
          </View>

          {/* Illustration */}
          <AmbulanceAnimation />

          {/* Title */}
          <Text style={styles.title}>Access all of Lumo</Text>

          {/* Features List */}
          <View style={styles.featuresContainer}>
            {features.map((feature, index) => (
              <View key={index} style={styles.featureItem}>
                {feature.icon}
                <Text style={styles.featureText}>{feature.text}</Text>
              </View>
            ))}
          </View>

          {/* Footer */}
          <View style={styles.footer}>
            <View style={styles.footerLinks}>
              <TouchableOpacity>
                <Text style={styles.footerLink}>Privacy Policy</Text>
              </TouchableOpacity>
              <Text style={styles.footerSeparator}> • </Text>
              <TouchableOpacity>
                <Text style={styles.footerLink}>Terms of Service</Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>

        {/* Fixed Floating Pricing Rectangle */}
        <View style={styles.fixedPricingContainer}>
          <View style={styles.pricingContainer}>
            <View style={styles.plansContainer}>
              {/* Yearly Plan */}
              <TouchableOpacity
                style={[
                  styles.planCard,
                  selectedPlan === 'yearly' && styles.planCardSelected,
                ]}
                onPress={() => handlePlanSelect('yearly')}
                activeOpacity={0.8}
              >
                {selectedPlan === 'yearly' && (
                  <View style={styles.saveBadge}>
                    <Text style={styles.saveBadgeText}>Save 20%</Text>
                  </View>
                )}
                <View style={styles.planContent}>
                  <View style={styles.planHeader}>
                    <Text style={styles.planName}>Yearly</Text>
                    {selectedPlan === 'yearly' ? (
                      <Svg width={24} height={24} viewBox="0 0 24 24">
                        <Circle cx="12" cy="12" r="8" fill={Colors.primary} />
                        <Path
                          d="M8 12l2 2 4-4"
                          stroke="#FFFFFF"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </Svg>
                    ) : (
                      <Svg width={24} height={24} viewBox="0 0 24 24">
                        <Circle cx="12" cy="12" r="8" stroke={Colors.dark.textSecondary} strokeWidth="2" fill="none" />
                      </Svg>
                    )}
                  </View>
                  <Text style={styles.planPrice}>£99.99<Text style={styles.planPeriod}>/year</Text></Text>
                  <Text style={styles.planMonthly}>£8.33/mo</Text>
                </View>
              </TouchableOpacity>

              {/* Monthly Plan */}
              <TouchableOpacity
                style={[
                  styles.planCard,
                  selectedPlan === 'monthly' && styles.planCardSelected,
                ]}
                onPress={() => handlePlanSelect('monthly')}
                activeOpacity={0.8}
              >
                <View style={styles.planContent}>
                  <View style={styles.planHeader}>
                    <Text style={styles.planName}>Monthly</Text>
                    {selectedPlan === 'monthly' ? (
                      <Svg width={24} height={24} viewBox="0 0 24 24">
                        <Circle cx="12" cy="12" r="8" fill={Colors.primary} />
                        <Path
                          d="M8 12l2 2 4-4"
                          stroke="#FFFFFF"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </Svg>
                    ) : (
                      <Svg width={24} height={24} viewBox="0 0 24 24">
                        <Circle cx="12" cy="12" r="8" stroke={Colors.dark.textSecondary} strokeWidth="2" fill="none" />
                      </Svg>
                    )}
                  </View>
                  <Text style={styles.planPrice}>£9.99<Text style={styles.planPeriod}>/mo</Text></Text>
                </View>
              </TouchableOpacity>
            </View>

            {/* Continue Button */}
            <TouchableOpacity
              style={[styles.continueButton, isLoading && styles.continueButtonDisabled]}
              onPress={handleSubscribe}
              disabled={isLoading}
              activeOpacity={0.9}
            >
              {isLoading ? (
                <ActivityIndicator size="small" color={Colors.white} />
              ) : (
                <Text style={styles.continueButtonText}>Continue</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  safeArea: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: 400, // Extra padding to account for fixed pricing container
  },
  fixedPricingContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
    paddingTop: Spacing.md,
    backgroundColor: 'transparent',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  closeButton: {
    width: 44,
    height: 44,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 22,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
  },
  illustrationContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Spacing.lg,
    marginBottom: Spacing.xl,
  },
  lottieAnimation: {
    width: 200,
    height: 200,
  },
  title: {
    fontSize: 32,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    textAlign: 'center',
    marginBottom: Spacing.xl,
  },
  featuresContainer: {
    marginBottom: Spacing.xl,
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  featureIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  featureText: {
    flex: 1,
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  pricingContainer: {
    backgroundColor: Colors.dark.surface,
    borderRadius: BorderRadius.xl,
    padding: Spacing.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 8,
  },
  plansContainer: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  planCard: {
    flex: 1,
    backgroundColor: Colors.dark.background,
    borderRadius: BorderRadius.lg,
    padding: Spacing.sm,
    borderWidth: 2,
    borderColor: Colors.dark.border,
    position: 'relative',
  },
  planCardSelected: {
    borderColor: Colors.primary,
  },
  saveBadge: {
    position: 'absolute',
    top: -10,
    left: '50%',
    marginLeft: -40,
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 4,
    borderRadius: BorderRadius.sm,
    zIndex: 1,
  },
  saveBadgeText: {
    fontSize: FontSize.xs,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  planContent: {
    paddingTop: Spacing.xs,
  },
  planHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  planName: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  planPrice: {
    fontSize: 20,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: 2,
  },
  planPeriod: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  planMonthly: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
  continueButton: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.lg,
    shadowColor: '#BB3E4F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.6,
    shadowRadius: 16,
    elevation: 10,
  },
  continueButtonDisabled: {
    opacity: 0.6,
  },
  continueButtonText: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  footer: {
    alignItems: 'center',
    marginTop: Spacing.lg,
  },
  footerLinks: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  footerLink: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.primary,
  },
  footerSeparator: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
});

