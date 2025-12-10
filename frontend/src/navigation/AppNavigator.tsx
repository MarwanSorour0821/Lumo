import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import OnboardingScreen from '../../screens/OnboardingScreen';
import { SignUpPersonalScreen } from '../screens/SignUpPersonalScreen';
import { SignUpCredentialsScreen } from '../screens/SignUpCredentialsScreen';
import { SignUpSexScreen } from '../screens/SignUpSexScreen';
import { SignUpAgeScreen } from '../screens/SignUpAgeScreen';
import { SignUpHeightScreen } from '../screens/SignUpHeightScreen';
import { SignUpWeightScreen } from '../screens/SignUpWeightScreen';
import { RootStackParamList } from '../types';
import { Colors } from '../constants/theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName="Onboarding"
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: Colors.dark.background },
        }}
      >
        <Stack.Screen name="Onboarding" component={OnboardingScreen} />
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

