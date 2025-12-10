import 'react-native-gesture-handler';
import React, { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { Text as RNText, TextInput as RNTextInput } from 'react-native';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { AppNavigator } from './src/navigation/AppNavigator';

// Keep the native splash screen visible while we load resources
SplashScreen.preventAutoHideAsync().catch(() => {
  // ignore if already prevented
});

export default function App() {
  // Cast to any to allow setting defaultProps for global font
  const TextAny = RNText as any;
  const TextInputAny = RNTextInput as any;

  const [fontsLoaded] = useFonts({
    'ProductSans-Regular': require('./assets/fonts/ProductSans/ProductSans-Regular.ttf'),
    'ProductSans-Bold': require('./assets/fonts/ProductSans/ProductSans-Bold.ttf'),
    'ProductSans-Italic': require('./assets/fonts/ProductSans/ProductSans-Italic.ttf'),
    'ProductSans-BoldItalic': require('./assets/fonts/ProductSans/ProductSans-BoldItalic.ttf'),
  });

  useEffect(() => {
    if (fontsLoaded) {
      if (!TextAny.defaultProps) TextAny.defaultProps = {};
      if (!TextInputAny.defaultProps) TextInputAny.defaultProps = {};
      TextAny.defaultProps.style = [TextAny.defaultProps.style, { fontFamily: 'ProductSans-Regular' }];
      TextInputAny.defaultProps.style = [TextInputAny.defaultProps.style, { fontFamily: 'ProductSans-Regular' }];

      // Hide splash once fonts are ready
      SplashScreen.hideAsync().catch(() => {
        /* ignore */
      });
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AppNavigator />
    </GestureHandlerRootView>
  );
}