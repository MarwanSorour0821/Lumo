import 'react-native-gesture-handler';
import React, { useEffect, useCallback } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { Text as RNText, TextInput as RNTextInput, View, ActivityIndicator } from 'react-native';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { AppNavigator } from './src/navigation/AppNavigator';
import { Colors } from './src/constants/theme';
import { AnalyseModalProvider } from './src/contexts/AnalyseModalContext';

// Keep the splash screen visible while we fetch resources
SplashScreen.preventAutoHideAsync();

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
      TextInputAny.defaultProps.style = [
        TextInputAny.defaultProps.style,
        { fontFamily: 'ProductSans-Regular' },
      ];
      // Disable platform autofill tints (yellow) and keep consistent focus color
      TextInputAny.defaultProps.autoCorrect = false;
      TextInputAny.defaultProps.autoCapitalize = 'none';
      TextInputAny.defaultProps.autoComplete = 'off';
      TextInputAny.defaultProps.textContentType = 'none';
      TextInputAny.defaultProps.importantForAutofill = 'no';
      TextInputAny.defaultProps.selectionColor = Colors.primary;
    }
  }, [fontsLoaded]);

  const onLayoutRootView = useCallback(async () => {
    if (fontsLoaded) {
      // Hide the native splash screen once fonts are loaded
      await SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return (
      <View style={{ flex: 1, backgroundColor: '#040404', justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }} onLayout={onLayoutRootView}>
      <AppNavigator />
    </GestureHandlerRootView>
  );
}