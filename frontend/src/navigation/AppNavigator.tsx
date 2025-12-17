import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import OnboardingScreen from '../../screens/OnboardingScreen';

import { SignUpPersonalScreen } from '../screens/SignUpPersonalScreen';
import { SignUpCredentialsScreen } from '../screens/SignUpCredentialsScreen';
import { SignUpSexScreen } from '../screens/SignUpSexScreen';
import { SignUpAgeScreen } from '../screens/SignUpAgeScreen';
import { SignUpHeightScreen } from '../screens/SignUpHeightScreen';
import { SignUpWeightScreen } from '../screens/SignUpWeightScreen';

import { LoginScreen } from '../screens/LoginScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { MyLabScreen } from '../screens/MyLabScreen';
import { ChatScreen } from '../screens/ChatScreen';
import { SettingsScreen } from '../screens/SettingsScreen';
import { NotificationSettingsScreen } from '../screens/NotificationSettingsScreen';
import { EditInformationScreen } from '../screens/EditInformationScreen';
import { AnalyseScreenWrapper } from '../screens/AnalyseScreenWrapper';

import { RootStackParamList } from '../types';
import { Colors } from '../constants/theme';
import { getCurrentSession } from '../lib/index';
import { AnalyseModalProvider } from '../contexts/AnalyseModalContext';

/** YOUR ANALYSIS-PAGE IMPORTS (kept) **/
import { SignUpBiometricsScreen } from '../screens/SignUpBiometricsScreen';
import { AnalysisResultsScreen } from '../screens/AnalysisResultsScreen';
import { TabNavigator } from './TabNavigator';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function AppNavigator() {
  const [isLoading, setIsLoading] = useState(true);
  const [initialRoute, setInitialRoute] = useState<keyof RootStackParamList>('Onboarding');

  useEffect(() => {
    const checkSession = async () => {
      try {
        const { data, error } = await getCurrentSession();
        if (data.user && !error) {
          setInitialRoute('Home');
        } else {
          setInitialRoute('Onboarding');
        }
      } catch (error) {
        setInitialRoute('Onboarding');
      } finally {
        setIsLoading(false);
      }
    };

    checkSession();
  }, []);

  if (isLoading) {
    // Return null - the custom splash screen in App.tsx handles the loading state
    return null;
  }

  return (
    <NavigationContainer>
      <AnalyseModalProvider>
        <Stack.Navigator
          initialRouteName={initialRoute}
          screenOptions={{
            headerShown: false,
            contentStyle: { backgroundColor: Colors.dark.background },
          }}
        >
        {/* MAIN BRANCH SCREENS (untouched) */}
        <Stack.Screen name="Onboarding" component={OnboardingScreen} />
        <Stack.Screen name="Login" component={LoginScreen} />

        <Stack.Screen
          name="Home"
          component={HomeScreen}
          options={{ animation: 'fade', animationDuration: 150 }}
        />

        <Stack.Screen
          name="MyLab"
          component={MyLabScreen}
          options={{ animation: 'fade', animationDuration: 150 }}
        />

        <Stack.Screen
          name="Chat"
          component={ChatScreen}
          options={{ animation: 'fade', animationDuration: 150 }}
        />

        <Stack.Screen
          name="Settings"
          component={SettingsScreen}
          options={{ animation: 'fade', animationDuration: 150 }}
        />
        <Stack.Screen
          name="Analyse"
          component={AnalyseScreenWrapper}
          options={{ animation: 'fade', animationDuration: 150 }}
        />

        <Stack.Screen name="EditInformation" component={EditInformationScreen} />
        <Stack.Screen name="NotificationSettings" component={NotificationSettingsScreen} />

        {/* SIGNUP FLOW (from main) */}
        <Stack.Screen name="SignUpPersonal" component={SignUpPersonalScreen} />
        <Stack.Screen name="SignUpCredentials" component={SignUpCredentialsScreen} />
        <Stack.Screen name="SignUpSex" component={SignUpSexScreen} />
        <Stack.Screen name="SignUpAge" component={SignUpAgeScreen} />
        <Stack.Screen name="SignUpHeight" component={SignUpHeightScreen} />
        <Stack.Screen name="SignUpWeight" component={SignUpWeightScreen} />

        {/* YOUR ANALYSIS-PAGE SCREENS (added safely) */}
        <Stack.Screen name="SignUpBiometrics" component={SignUpBiometricsScreen} />
        <Stack.Screen name="AnalysisResults" component={AnalysisResultsScreen} />
        <Stack.Screen name="MainApp" component={TabNavigator} />
      </Stack.Navigator>
      </AnalyseModalProvider>
    </NavigationContainer>
  );
}
