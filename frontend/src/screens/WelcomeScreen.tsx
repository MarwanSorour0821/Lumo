import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Button } from '../components/Button';
import { Colors, FontSize, FontWeight, Spacing } from '../constants/theme';
import { RootStackParamList } from '../types';

type WelcomeScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Welcome'>;
};

export function WelcomeScreen({ navigation }: WelcomeScreenProps) {
  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <View style={styles.backgroundContainer}>
        {/* Gradient overlay for the blood tube aesthetic */}
        <View style={styles.gradient} />
      </View>
      
      <SafeAreaView style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.logo}>LUMO</Text>
          <Text style={styles.tagline}>Your Health, Illuminated</Text>
        </View>
        
        <View style={styles.heroSection}>
          <Text style={styles.heroTitle}>Take Control of{'\n'}Your Blood Health</Text>
          <Text style={styles.heroSubtitle}>
            Track, analyze, and understand your blood test results with AI-powered insights.
          </Text>
        </View>
        
        <View style={styles.buttonContainer}>
          <Button
            title="Get Started"
            onPress={() => navigation.navigate('SignUpPersonal')}
            variant="primary"
          />
          
          <View style={styles.signInContainer}>
            <Text style={styles.signInText}>Already have an account? </Text>
            <Text style={styles.signInLink}>Sign In</Text>
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
  backgroundContainer: {
    ...StyleSheet.absoluteFillObject,
  },
  gradient: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  content: {
    flex: 1,
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
  },
  header: {
    alignItems: 'center',
    paddingTop: Spacing.xxl,
  },
  logo: {
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.primary,
    letterSpacing: 8,
  },
  tagline: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
    marginTop: Spacing.xs,
    letterSpacing: 2,
  },
  heroSection: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  heroTitle: {
    fontSize: FontSize.xxxl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    textAlign: 'center',
    lineHeight: 48,
  },
  heroSubtitle: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginTop: Spacing.md,
    lineHeight: 24,
    paddingHorizontal: Spacing.lg,
  },
  buttonContainer: {
    paddingBottom: Spacing.xxl,
  },
  signInContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: Spacing.lg,
  },
  signInText: {
    color: Colors.dark.textSecondary,
    fontSize: FontSize.sm,
  },
  signInLink: {
    color: Colors.primary,
    fontSize: FontSize.sm,
    fontWeight: FontWeight.semibold,
  },
});

