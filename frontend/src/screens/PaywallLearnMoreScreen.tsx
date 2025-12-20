import React from 'react';
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
import { usePaywall } from '../contexts/PaywallContext';

interface PaywallLearnMoreScreenProps {
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

// Feature Icons with circular backgrounds
const MagnifyingGlassIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Circle cx="11" cy="11" r="8" stroke={Colors.white} strokeWidth="2" />
      <Path d="m21 21-4.35-4.35" stroke={Colors.white} strokeWidth="2" strokeLinecap="round" />
    </Svg>
  </View>
);

const BooksIcon = () => (
  <View style={styles.featureIcon}>
    <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
      <Path
        d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <Path
        d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <Path
        d="M4 7.5A2.5 2.5 0 0 1 6.5 5H20"
        stroke={Colors.white}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
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

const features = [
  { icon: <MagnifyingGlassIcon />, text: 'Unlimited blood test analyses' },
  { icon: <BooksIcon />, text: 'Access 1000+ food databases' },
  { icon: <HeartIcon />, text: 'Apple Health integration' },
  { icon: <SmartphoneIcon />, text: 'Widgets, reminders, and more' },
];

export function PaywallLearnMoreScreen({ navigation }: PaywallLearnMoreScreenProps) {
  const { hasActiveSubscription } = usePaywall();

  const handleLearnMore = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    // Don't show paywall if user already has subscription
    if (!hasActiveSubscription) {
      navigation.navigate('PaywallMain');
    }
  };

  return (
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Close Button */}
          <View style={styles.header}>
            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.navigate('Home');
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
          <Text style={styles.title}>
            Unlock the full{'\n'}Lumo experience
          </Text>

          {/* Features List */}
          <View style={styles.featuresContainer}>
            {features.map((feature, index) => (
              <View key={index} style={styles.featureItem}>
                {feature.icon}
                <Text style={styles.featureText}>{feature.text}</Text>
              </View>
            ))}
          </View>

          {/* Learn More Button */}
          <TouchableOpacity
            style={styles.learnMoreButton}
            onPress={handleLearnMore}
            activeOpacity={0.9}
          >
            <Text style={styles.learnMoreButtonText}>Learn More</Text>
          </TouchableOpacity>
        </ScrollView>
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
    paddingBottom: Spacing.xl,
    alignItems: 'center',
  },
  header: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'flex-end',
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
    marginTop: Spacing.lg,
    marginBottom: Spacing.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 32,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    textAlign: 'center',
    marginBottom: Spacing.xl,
    lineHeight: 40,
  },
  featuresContainer: {
    width: '100%',
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
  learnMoreButton: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 16,
    shadowColor: '#BB3E4F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.6,
    shadowRadius: 16,
  },
  learnMoreButtonText: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
});

