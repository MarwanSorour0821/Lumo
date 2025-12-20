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

interface PaywallWelcomeScreenProps {
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

export function PaywallWelcomeScreen({ navigation }: PaywallWelcomeScreenProps) {
  const handleContinue = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    navigation.navigate('Home');
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
            24 hours, on me 👋
          </Text>

          {/* Description */}
          <View style={styles.descriptionContainer}>
            <Text style={styles.description}>
              I'd love for you to try the app. Here's a 24-hour trial on me. Nothing you need to do, it's already activated.
            </Text>
            <Text style={styles.description}>
              I wish I could offer a free plan or make this longer, but for transparency I'm using extremely expensive AI providers to power Lumo and simply can't afford to do it.
            </Text>
            <Text style={styles.boldDescription}>
              No credit card required. Just enjoy!
            </Text>
          </View>

          {/* Developer & Cat */}
          <View style={styles.profileContainer}>
            <View style={styles.profilePictures}>
              <View style={styles.profileCircle}>
                <Text style={styles.profileEmoji}>👨‍💻</Text>
              </View>
              <View style={styles.profileCircle}>
                <Text style={styles.profileEmoji}>🐱</Text>
              </View>
            </View>
            <Text style={styles.profileName}>Developer & Lumo</Text>
          </View>

          {/* Continue Button */}
          <TouchableOpacity
            style={styles.continueButton}
            onPress={handleContinue}
            activeOpacity={0.9}
          >
            <Text style={styles.continueButtonText}>Sounds good!</Text>
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
    marginBottom: Spacing.lg,
  },
  descriptionContainer: {
    width: '100%',
    marginBottom: Spacing.xl,
  },
  description: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    lineHeight: 22,
    marginBottom: Spacing.md,
    textAlign: 'center',
  },
  boldDescription: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    textAlign: 'center',
    marginTop: Spacing.sm,
  },
  profileContainer: {
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  profilePictures: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.sm,
  },
  profileCircle: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: Colors.dark.surface,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: Colors.primary,
  },
  profileEmoji: {
    fontSize: 30,
  },
  profileName: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  continueButton: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  continueButtonText: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
});

