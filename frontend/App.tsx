import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View, Animated } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import OnboardingScreen from './screens/OnboardingScreen';
import { useTheme } from './hooks/useTheme';

export default function App() {
  const [splashVisible, setSplashVisible] = useState(true);
  const theme = useTheme();
  const fadeAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Hide splash screen after 2 seconds with fade animation
    const timer = setTimeout(() => {
      Animated.timing(fadeAnim, {
        toValue: 0,
        duration: 500,
        useNativeDriver: true,
      }).start(() => {
        setSplashVisible(false);
      });
    }, 2000);

    return () => clearTimeout(timer);
  }, [fadeAnim]);

  const handleGetStarted = () => {
    // Handle navigation to next screen
    console.log('Get Started pressed');
  };

  if (splashVisible) {
    return (
      <Animated.View style={[styles.splashContainer, { opacity: fadeAnim }]}>
        <Text style={styles.splashText}>Lumo</Text>
        <StatusBar style="light" />
      </Animated.View>
    );
  }

  return (
    <OnboardingScreen 
      theme={theme} 
      onGetStarted={handleGetStarted}
    />
  );
}

const styles = StyleSheet.create({
  splashContainer: {
    flex: 1,
    backgroundColor: '#000',
    alignItems: 'center',
    justifyContent: 'center',
  },
  splashText: {
    fontSize: 64,
    fontWeight: 'bold',
    color: '#fff',
    letterSpacing: 4,
  },
});
