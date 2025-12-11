import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { WelcomeScreen } from '../screens/WelcomeScreen';
import { SignUpPersonalScreen } from '../screens/SignUpPersonalScreen';
import { SignUpBiometricsScreen } from '../screens/SignUpBiometricsScreen';
import { AnalysisResultsScreen } from '../screens/AnalysisResultsScreen';
import { TabNavigator } from './TabNavigator';
import { RootStackParamList } from '../types';
import { Colors } from '../constants/theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName="Welcome"
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: Colors.dark.background },
        }}
      >
        <Stack.Screen name="Welcome" component={WelcomeScreen} />
        <Stack.Screen name="SignUpPersonal" component={SignUpPersonalScreen} />
        <Stack.Screen name="SignUpBiometrics" component={SignUpBiometricsScreen} />
        <Stack.Screen name="MainApp" component={TabNavigator} />
        <Stack.Screen name="AnalysisResults" component={AnalysisResultsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

