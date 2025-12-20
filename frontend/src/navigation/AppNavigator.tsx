import React, { useEffect, useState, useRef } from 'react';
import { NavigationContainer, NavigationContainerRef } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import * as Linking from 'expo-linking';
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
import { PaywallProvider, usePaywall } from '../contexts/PaywallContext';

/** YOUR ANALYSIS-PAGE IMPORTS (kept) **/
import { SignUpBiometricsScreen } from '../screens/SignUpBiometricsScreen';
import { AnalysisResultsScreen } from '../screens/AnalysisResultsScreen';
import { TabNavigator } from './TabNavigator';

/** PAYWALL SCREENS **/
import { PaywallMainScreen } from '../screens/PaywallMainScreen';

const Stack = createNativeStackNavigator<RootStackParamList>();

// Deep linking configuration for production app
// Scheme is 'Lumo' as defined in app.json
const linking = {
  prefixes: ['Lumo://', 'lumo://'],
  config: {
    screens: {
      Settings: 'settings',
      Home: 'home',
      // Stripe callbacks (subscription-success, subscription-cancel) are handled 
      // via the URL listener in AppNavigatorContent, not mapped to screens
    },
  },
};

// Inner component that has access to PaywallContext
function AppNavigatorContent({ initialRoute }: { initialRoute: keyof RootStackParamList }) {
  const navigationRef = useRef<NavigationContainerRef<RootStackParamList>>(null);
  const { refreshSubscriptionStatus } = usePaywall();

  // Handle deep links for Stripe callbacks
  useEffect(() => {
    // Handle the initial URL (app was opened via deep link)
    const handleInitialURL = async () => {
      const url = await Linking.getInitialURL();
      if (url) {
        handleDeepLink(url);
      }
    };

    // Handle URLs when app is already open
    const subscription = Linking.addEventListener('url', (event) => {
      handleDeepLink(event.url);
    });

    handleInitialURL();

    return () => {
      subscription.remove();
    };
  }, [refreshSubscriptionStatus]);

  const handleDeepLink = async (url: string) => {
    console.log('Deep link received:', url);
    
    try {
      const { path, queryParams } = Linking.parse(url);
      console.log('Parsed deep link:', { path, queryParams });

      if (path === 'subscription-success') {
        // Stripe checkout was successful - refresh subscription status
        console.log('Subscription success callback received');
        await refreshSubscriptionStatus();
        
        // Navigate to Settings to show the updated subscription status
        if (navigationRef.current?.isReady()) {
          // Close any modals first
          navigationRef.current.reset({
            index: 0,
            routes: [{ name: 'Home' }],
          });
          // Then navigate to Settings
          setTimeout(() => {
            navigationRef.current?.navigate('Settings');
          }, 100);
        }
      } else if (path === 'subscription-cancel') {
        // User cancelled checkout - just log it
        console.log('Subscription cancelled by user');
      } else if (path === 'settings') {
        // Return from Stripe portal
        console.log('Returned from Stripe portal');
        await refreshSubscriptionStatus();
        if (navigationRef.current?.isReady()) {
          navigationRef.current.navigate('Settings');
        }
      }
    } catch (error) {
      console.error('Error handling deep link:', error);
    }
  };

  return (
    <NavigationContainer ref={navigationRef} linking={linking}>
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

          {/* PAYWALL SCREENS */}
          <Stack.Screen 
            name="PaywallMain" 
            component={PaywallMainScreen}
            options={{ 
              presentation: 'card',
              animation: 'slide_from_bottom'
            }}
          />
        </Stack.Navigator>
      </AnalyseModalProvider>
    </NavigationContainer>
  );
}

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
    <PaywallProvider>
      <AppNavigatorContent initialRoute={initialRoute} />
    </PaywallProvider>
  );
}
