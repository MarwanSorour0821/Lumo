import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View, Animated } from 'react-native';
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
  const mainTextFade = useRef(new Animated.Value(0)).current;
  const mainTextSlide = useRef(new Animated.Value(30)).current;
  const subTextFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Animate main text: fade in + slide up
    Animated.parallel([
      Animated.timing(mainTextFade, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.timing(mainTextSlide, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      }),
    ]).start();

    // Animate sub text: fade in only (with delay)
    Animated.timing(subTextFade, {
      toValue: 1,
      duration: 600,
      delay: 200,
      useNativeDriver: true,
    }).start();

    // Animate button: fade in (with delay)
    Animated.timing(buttonFade, {
      toValue: 1,
      duration: 600,
      delay: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  return (
    <View style={[styles.container, { backgroundColor: themeColors.background }]}>
      <StatusBar style={theme === 'dark' ? 'light' : 'dark'} />
      
      <View style={styles.bottomSection}>
        <View style={styles.content}>
          <Animated.Text 
            style={[
              styles.mainText, 
              { 
                color: themeColors.primaryText,
                opacity: mainTextFade,
                transform: [{ translateY: mainTextSlide }],
              }
            ]}
          >
            Top-class premium{'\n'}analysis on your{'\n'}blood tests at your{'\n'}finger tips.
          </Animated.Text>
          
          <Animated.Text 
            style={[
              styles.subText, 
              { 
                color: themeColors.secondaryText,
                opacity: subTextFade,
              }
            ]}
          >
            Create an account and join over 100,000{'\n'}people who are already using our app.
          </Animated.Text>
        </View>

        <Animated.View
          style={{
            opacity: buttonFade,
          }}
        >
          <PrimaryButton 
            text="Get Started"
            theme={theme}
            onPress={onGetStarted}
          />
        </Animated.View>
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

