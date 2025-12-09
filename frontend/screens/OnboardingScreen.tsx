import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { PrimaryButton } from '../components';
import { colors, Theme } from '../constants/theme';

interface OnboardingScreenProps {
  theme?: Theme;
  onGetStarted?: () => void;
}

export default function OnboardingScreen({ 
  theme = 'dark',
  onGetStarted 
}: OnboardingScreenProps) {
  const themeColors = colors[theme];


  return (
    <View style={[styles.container, { backgroundColor: themeColors.background }]}>
      <StatusBar style={theme === 'dark' ? 'light' : 'dark'} />
      
      <View style={styles.bottomSection}>
        <View style={styles.content}>
          <Text style={[styles.mainText, { color: themeColors.primaryText }]}>
            Top-class premium{'\n'}analysis on your{'\n'}blood tests at your{'\n'}finger tips.
          </Text>
          
          <Text style={[styles.subText, { color: themeColors.secondaryText }]}>
            Create an account and join over 100,000{'\n'}people who are already using our app.
          </Text>
        </View>

        <PrimaryButton 
          text="Get Started"
          theme={theme}
          onPress={onGetStarted}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 24,
  },
  bottomSection: {
    flex: 1,
    justifyContent: 'flex-end',
    paddingBottom: 40,
  },
  content: {
    marginBottom: 32,
  },
  mainText: {
    fontSize: 40,
    fontWeight: 'normal',
    textAlign: 'center',
    lineHeight: 40,
    marginBottom: 24,
  },
  subText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
  },
});

