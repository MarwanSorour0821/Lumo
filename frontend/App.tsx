import 'react-native-gesture-handler';
import React, { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { ActivityIndicator, Text as RNText, TextInput as RNTextInput } from 'react-native';
import { useFonts } from 'expo-font';
import { AppNavigator } from './src/navigation/AppNavigator';

export default function App() {
  const [fontsLoaded] = useFonts({
    'ProductSans-Regular': require('./assets/fonts/ProductSans/ProductSans-Regular.ttf'),
    'ProductSans-Bold': require('./assets/fonts/ProductSans/ProductSans-Bold.ttf'),
    'ProductSans-Italic': require('./assets/fonts/ProductSans/ProductSans-Italic.ttf'),
    'ProductSans-BoldItalic': require('./assets/fonts/ProductSans/ProductSans-BoldItalic.ttf'),
  });

  useEffect(() => {
    if (fontsLoaded) {
      if (!RNText.defaultProps) RNText.defaultProps = {};
      if (!RNTextInput.defaultProps) RNTextInput.defaultProps = {};
      RNText.defaultProps.style = [RNText.defaultProps.style, { fontFamily: 'ProductSans-Regular' }];
      RNTextInput.defaultProps.style = [RNTextInput.defaultProps.style, { fontFamily: 'ProductSans-Regular' }];
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return (
      <GestureHandlerRootView style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator color="#B01328" />
      </GestureHandlerRootView>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AppNavigator />
    </GestureHandlerRootView>
  );
}