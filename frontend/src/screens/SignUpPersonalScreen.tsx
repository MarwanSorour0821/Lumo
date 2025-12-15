import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Animated,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import Svg, { Path } from 'react-native-svg';
import { Input } from '../components/Input';
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, AppleSignUpData } from '../types';
import { signInWithApple } from '../lib/supabase';

// Apple Logo Icon Component
const AppleIcon = ({ size = 24, color = '#000000' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24">
    <Path
      fill={color}
      d="M14.94 5.19A4.38 4.38 0 0 0 16 2a4.44 4.44 0 0 0-3 1.52a4.17 4.17 0 0 0-1 3.09a3.69 3.69 0 0 0 2.94-1.42Zm2.52 7.44a4.51 4.51 0 0 1 2.16-3.81a4.66 4.66 0 0 0-3.66-2c-1.56-.16-3 .91-3.83.91s-2-.89-3.3-.87a4.92 4.92 0 0 0-4.14 2.53C2.93 12.45 4.24 17 6 19.47c.8 1.21 1.8 2.58 3.12 2.53s1.75-.82 3.28-.82s2 .82 3.3.79s2.22-1.24 3.06-2.45a11 11 0 0 0 1.38-2.85a4.41 4.41 0 0 1-2.68-4.04Z"
    />
  </Svg>
);

type SignUpPersonalScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpPersonal'>;
};

export function SignUpPersonalScreen({ navigation }: SignUpPersonalScreenProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isAppleLoading, setIsAppleLoading] = useState(false);
  const headingFade = useRef(new Animated.Value(0)).current;
  const inputsFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Animate heading
    Animated.timing(headingFade, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();

    // Animate inputs with delay
    Animated.timing(inputsFade, {
      toValue: 1,
      duration: 600,
      delay: 200,
      useNativeDriver: true,
    }).start();

    // Animate button with delay
    Animated.timing(buttonFade, {
      toValue: 1,
      duration: 600,
      delay: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  const validateForm = () => {
    const newErrors: Record<string, string> = {};
    
    if (!firstName.trim()) {
      newErrors.firstName = 'First name is required';
    }
    if (!lastName.trim()) {
      newErrors.lastName = 'Last name is required';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleContinue = () => {
    if (validateForm()) {
      console.log('SignUpPersonalScreen - Navigating with:', {
        firstName: firstName || '(empty)',
        lastName: lastName || '(empty)'
      });
      
      navigation.navigate('SignUpCredentials', {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      });
    }
  };

  const handleAppleSignIn = async () => {
    setIsAppleLoading(true);
    try {
      const { data, error } = await signInWithApple();
      
      if (error) {
        if (error.message !== 'Sign in cancelled') {
          Alert.alert('Sign In Error', error.message);
        }
        setIsAppleLoading(false);
        return;
      }

      if (data.user) {
        // Create Apple sign up data and continue to biometrics
        const appleSignUpData: AppleSignUpData = {
          userId: data.user.id,
          email: data.user.email,
          firstName: firstName || undefined,
          lastName: lastName || undefined,
          isAppleSignIn: true,
        };

        setIsAppleLoading(false);
        // Skip credentials and go directly to sex selection
        navigation.navigate('SignUpSex', { signUpData: appleSignUpData });
      } else {
        Alert.alert('Sign In Error', 'Failed to get user information');
        setIsAppleLoading(false);
      }
    } catch (error: any) {
      Alert.alert('Sign In Error', error.message || 'An unexpected error occurred');
      setIsAppleLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.headerContainer}>
          <BackButton
            onPress={() => navigation.goBack()}
            theme="dark"
          />
        </View>
        <ProgressBar currentStep={1} totalSteps={7} />
        
        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        >
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.headingContainer}>
              <Animated.Text 
                style={[
                  styles.heading,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                What should we call you?
              </Animated.Text>
              
              <Animated.View 
                style={[
                  styles.inputsContainer,
                  {
                    opacity: inputsFade,
                  }
                ]}
              >
                <View style={styles.halfInput}>
                  <Input
                    label="First Name"
                    value={firstName}
                    onChangeText={setFirstName}
                    placeholder="John"
                    autoCapitalize="words"
                    error={errors.firstName}
                    isDark={true}
                    variant="underline"
                  />
                </View>
                <View style={styles.halfInput}>
                  <Input
                    label="Last Name"
                    value={lastName}
                    onChangeText={setLastName}
                    placeholder="Doe"
                    autoCapitalize="words"
                    error={errors.lastName}
                    isDark={true}
                    variant="underline"
                  />
                </View>
              </Animated.View>
            </View>
          
          {/* Apple Sign In Button */}
          <Animated.View 
            style={[
              styles.appleButtonContainer,
              { opacity: buttonFade }
            ]}
          >
            <TouchableOpacity
              style={styles.appleButton}
              onPress={handleAppleSignIn}
              disabled={isAppleLoading}
              activeOpacity={0.8}
            >
              {isAppleLoading ? (
                <ActivityIndicator color="#000000" size="small" />
              ) : (
                <>
                  <AppleIcon size={20} color="#000000" />
                  <Text style={styles.appleButtonText}>Continue with Apple</Text>
                </>
              )}
            </TouchableOpacity>
          </Animated.View>
          
          <Animated.View 
            style={[
              styles.buttonContainer,
              {
                opacity: buttonFade,
              }
            ]}
          >
            <PrimaryButton
              text="Continue"
              onPress={handleContinue}
              theme="dark"
            />
          </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  safeArea: {
    flex: 1,
  },
  headerContainer: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingVertical: Spacing.lg,
  },
  headingContainer: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    paddingBottom: Spacing.md,
  },
  heading: {
    fontSize: 40,
    lineHeight: 40,
    marginBottom: 32,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
  },
  inputsContainer: {
    flexDirection: 'column',
    gap: Spacing.md,
  },
  row: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  halfInput: {
    width: '100%',
  },
  socialButtons: {
    marginTop: Spacing.lg,
  },
  socialSpacer: {
    height: Spacing.sm,
  },
  appleIcon: {
    fontSize: 18,
    color: Colors.black,
  },
  googleIcon: {
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: '#4285F4',
  },
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
  appleButtonContainer: {
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.md,
  },
  appleButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.white,
    borderRadius: BorderRadius.full,
    paddingVertical: 14,
    paddingHorizontal: 24,
    gap: Spacing.sm,
  },
  appleButtonText: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: '#000000',
  },
});

