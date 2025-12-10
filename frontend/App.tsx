import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View, Animated } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppNavigator } from './src/navigation/AppNavigator';

export default function App() {
  const [fontsLoaded] = useFonts({
    'ProductSans-Regular': require('./assets/fonts/Product Sans Font/Product Sans Regular.ttf'),
    'ProductSans-Bold': require('./assets/fonts/Product Sans Font/Product Sans Bold.ttf'),
    'ProductSans-Italic': require('./assets/fonts/Product Sans Font/Product Sans Italic.ttf'),
    'ProductSans-BoldItalic': require('./assets/fonts/Product Sans Font/Product Sans Bold Italic.ttf'),
  });
  const [splashVisible, setSplashVisible] = useState(true);
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

  // Wait for fonts before rendering anything
  if (!fontsLoaded) {
    return null;
  }

  if (splashVisible) {
    return (
      <Animated.View style={[styles.splashContainer, { opacity: fadeAnim }]}>
        <Text style={styles.splashText}>Lumo</Text>
        <StatusBar style="light" />
      </Animated.View>
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <AppNavigator />
    </SafeAreaProvider>
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
    fontFamily: 'ProductSans-Bold',
    color: '#fff',
    letterSpacing: 4,
  },
});