import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg, { Path, Circle, G } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

interface PaywallMainScreenProps {
  navigation: any;
}

// Cat reaching for crown illustration
const CatCrownIllustration = () => (
  <View style={styles.illustrationContainer}>
    <Svg width={200} height={200} viewBox="0 0 200 200">
      {/* Background decorative shapes */}
      <Circle cx="50" cy="50" r="3" fill={Colors.primary} opacity={0.3} />
      <Circle cx="150" cy="80" r="4" fill={Colors.primary} opacity={0.3} />
      <Path
        d="M30 120 Q40 110 50 120 T70 120"
        stroke={Colors.primary}
        strokeWidth="2"
        fill="none"
        opacity={0.3}
      />
      
      {/* Cat body */}
      <Path
        d="M80 140 Q70 120 60 130 Q50 140 60 150 Q70 160 80 150 Q90 160 100 150 Q110 140 100 130 Q90 120 80 140"
        fill="#FFFFFF"
        stroke={Colors.primary}
        strokeWidth="2"
      />
      
      {/* Cat head */}
      <Circle cx="80" cy="120" r="25" fill="#FFFFFF" stroke={Colors.primary} strokeWidth="2" />
      
      {/* Cat eye */}
      <Circle cx="75" cy="118" r="2" fill="#000000" />
      
      {/* Cat paw reaching up */}
      <Path
        d="M95 110 Q100 100 105 110"
        stroke={Colors.primary}
        strokeWidth="3"
        strokeLinecap="round"
      />
      
      {/* Crown */}
      <G transform="translate(120, 60)">
        <Path
          d="M0 20 L10 0 L20 20 L15 20 L15 30 L5 30 L5 20 Z"
          fill={Colors.primary}
        />
        <Circle cx="5" cy="5" r="2" fill="#FFD700" />
        <Circle cx="15" cy="5" r="2" fill="#FFD700" />
      </G>
      
      {/* Stars around crown */}
      <Path
        d="M110 50 L112 45 L114 50 L119 52 L114 54 L112 59 L110 54 L105 52 Z"
        fill={Colors.primary}
        opacity={0.7}
      />
      <Path
        d="M130 70 L131 67 L132 70 L135 71 L132 72 L131 75 L130 72 L127 71 Z"
        fill={Colors.primary}
        opacity={0.7}
      />
    </Svg>
  </View>
);

// Feature Icons
const MagnifyingGlassIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Circle cx="11" cy="11" r="8" stroke={Colors.white} strokeWidth="2" />
      <Path d="m21 21-4.35-4.35" stroke={Colors.white} strokeWidth="2" strokeLinecap="round" />
    </Svg>
  </View>
);

const HeartIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"
        fill={Colors.white}
      />
    </Svg>
  </View>
);

const SmartphoneIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M17 2H7a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z"
        stroke={Colors.white}
        strokeWidth="2"
        fill="none"
      />
      <Path d="M12 18h.01" stroke={Colors.white} strokeWidth="2" strokeLinecap="round" />
    </Svg>
  </View>
);

const LightningIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
        fill={Colors.white}
      />
    </Svg>
  </View>
);

const TargetIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Circle cx="12" cy="12" r="10" stroke={Colors.white} strokeWidth="2" fill="none" />
      <Circle cx="12" cy="12" r="6" stroke={Colors.white} strokeWidth="2" fill="none" />
      <Circle cx="12" cy="12" r="2" fill={Colors.white} />
    </Svg>
  </View>
);

const AlarmIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Circle cx="12" cy="12" r="10" stroke={Colors.white} strokeWidth="2" fill="none" />
      <Path d="M12 6v6l4 2" stroke={Colors.white} strokeWidth="2" strokeLinecap="round" />
    </Svg>
  </View>
);

const features = [
  { icon: <MagnifyingGlassIcon />, text: 'Unlimited blood test analyses' },
  { icon: <HeartIcon />, text: 'Apple Health integration' },
  { icon: <SmartphoneIcon />, text: 'Home and lock screen widgets' },
  { icon: <LightningIcon />, text: 'Quick save analyses' },
  { icon: <TargetIcon />, text: 'Accountability features' },
  { icon: <AlarmIcon />, text: 'Reminders' },
];

export function PaywallMainScreen({ navigation }: PaywallMainScreenProps) {
  const [selectedPlan, setSelectedPlan] = useState<'monthly' | 'yearly'>('yearly');

  const handlePlanSelect = (plan: 'monthly' | 'yearly') => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSelectedPlan(plan);
  };

  const handleSubscribe = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    // TODO: Implement subscription logic
    console.log('Subscribe to plan:', selectedPlan);
    // Reset navigation stack to prevent going back to paywall
    navigation.reset({
      index: 0,
      routes: [{ name: 'Home' }],
    });
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
              style={styles.backButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.navigate('PaywallLearnMore');
              }}
              activeOpacity={0.7}
            >
              <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M19 12H5M12 19l-7-7 7-7"
                  stroke={Colors.white}
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
              <Text style={styles.backText}>Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.navigate('PaywallWelcome');
              }}
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
          <CatCrownIllustration />

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

            {/* Nothing due today */}
            <Text style={styles.nothingDueText}>Nothing due today</Text>

            {/* Continue Button */}
            <TouchableOpacity
              style={styles.continueButton}
              onPress={handleSubscribe}
              activeOpacity={0.9}
            >
              <Text style={styles.continueButtonText}>Continue</Text>
            </TouchableOpacity>

            {/* Trial Text */}
            <Text style={styles.trialText}>3-day free trial, then £99.99/year</Text>
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
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
  },
  backText: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
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
  nothingDueText: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.success,
    textAlign: 'center',
    marginTop: Spacing.md,
    marginBottom: Spacing.md,
  },
  trialText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginTop: Spacing.md,
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

