import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ActivityIndicator, View } from 'react-native';
import OnboardingScreen from '../../screens/OnboardingScreen';
import { SignUpPersonalScreen } from '../screens/SignUpPersonalScreen';
import { SignUpCredentialsScreen } from '../screens/SignUpCredentialsScreen';
import { SignUpSexScreen } from '../screens/SignUpSexScreen';
import { SignUpAgeScreen } from '../screens/SignUpAgeScreen';
import { SignUpHeightScreen } from '../screens/SignUpHeightScreen';
import { SignUpWeightScreen } from '../screens/SignUpWeightScreen';
import { LoginScreen } from '../screens/LoginScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { RootStackParamList } from '../types';
import { Colors } from '../constants/theme';
import { getCurrentSession } from '../lib/supabase';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  const [isLoading, setIsLoading] = useState(true);
  const [initialRoute, setInitialRoute] = useState<keyof RootStackParamList>('Onboarding');

  useEffect(() => {
    // Check if user is already signed in
    const checkSession = async () => {
      try {
        const { data, error } = await getCurrentSession();
        if (data.user && !error) {
          // User is authenticated, go to Home
          setInitialRoute('Home');
        } else {
          // No session, go to Onboarding
          setInitialRoute('Onboarding');
        }
      } catch (error) {
        // On error, default to Onboarding
        setInitialRoute('Onboarding');
      } finally {
        setIsLoading(false);
      }
    };

    checkSession();
  }, []);

  if (isLoading) {
    return (
      <View style={{ flex: 1, backgroundColor: Colors.dark.background, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName={initialRoute}
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: Colors.dark.background },
        }}
      >
        <Stack.Screen name="Onboarding" component={OnboardingScreen} />
        <Stack.Screen name="Login" component={LoginScreen} />
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="SignUpPersonal" component={SignUpPersonalScreen} />
        <Stack.Screen name="SignUpCredentials" component={SignUpCredentialsScreen} />
        <Stack.Screen name="SignUpSex" component={SignUpSexScreen} />
        <Stack.Screen name="SignUpAge" component={SignUpAgeScreen} />
        <Stack.Screen name="SignUpHeight" component={SignUpHeightScreen} />
        <Stack.Screen name="SignUpWeight" component={SignUpWeightScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

