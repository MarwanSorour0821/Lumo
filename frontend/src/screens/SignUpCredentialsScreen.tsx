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
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import Svg, { Path } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { Alert, ActivityIndicator } from 'react-native';
import { Colors, FontSize, FontWeight, Spacing } from '../constants/theme';
import { RootStackParamList, BiologicalSex, SignUpData, AppleSignUpData } from '../types';
import { signUpWithEmail, createUserProfile } from '../lib/supabase';

type SignUpCredentialsScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpCredentials'>;
  route: RouteProp<RootStackParamList, 'SignUpCredentials'>;
};

// Helper to check if signUpData is from Apple Sign In
const isAppleSignIn = (data: SignUpData | AppleSignUpData): data is AppleSignUpData => {
  return 'isAppleSignIn' in data && data.isAppleSignIn === true;
};

export function SignUpCredentialsScreen({ navigation, route }: SignUpCredentialsScreenProps) {
  const { 
    firstName, 
    lastName, 
    signUpData, 
    sex, 
    age, 
    height, 
    heightFeet, 
    heightInches, 
    heightUnit, 
    weight, 
    weightUnit 
  } = route.params;
  
  // Pre-fill email if available (e.g., from Apple Sign In)
  const initialEmail = isAppleSignIn(signUpData) ? (signUpData.email || '') : '';
  const [email, setEmail] = useState(initialEmail);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isCreatingAccount, setIsCreatingAccount] = useState(false);
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
    const isAppleUser = isAppleSignIn(signUpData);
    
    if (!email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      newErrors.email = 'Please enter a valid email';
    }
    
    // Only validate password for non-Apple Sign In users
    if (!isAppleUser) {
      if (!password) {
        newErrors.password = 'Password is required';
      } else if (password.length < 8) {
        newErrors.password = 'Password must be at least 8 characters';
      }
      if (password !== confirmPassword) {
        newErrors.confirmPassword = 'Passwords do not match';
      }
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleContinue = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!validateForm()) {
      return;
    }

    setIsCreatingAccount(true);

    try {
      // Calculate date of birth from age
      const ageNum = parseInt(age, 10);
      const today = new Date();
      const birthYear = today.getFullYear() - ageNum;
      const dateOfBirth = new Date(birthYear, today.getMonth(), today.getDate());

      // Convert height to cm
      let heightInCm: number;
      if (heightUnit === 'cm') {
        heightInCm = parseInt(height, 10);
      } else {
        const feetNum = parseInt(heightFeet || '0', 10);
        const inchesNum = parseInt(heightInches || '0', 10);
        heightInCm = feetNum * 30.48 + inchesNum * 2.54;
      }

      // Convert weight to kg
      let weightInKg: number;
      if (weightUnit === 'kg') {
        weightInKg = parseFloat(weight);
      } else {
        weightInKg = parseFloat(weight) * 0.453592;
      }

      let userId: string;

      // Check if this is an Apple Sign In user (already authenticated)
      if (isAppleSignIn(signUpData)) {
        // User is already authenticated via Apple, use their ID directly
        userId = signUpData.userId;
      } else {
        // Regular sign up with email/password
        const { data: authData, error: authError } = await signUpWithEmail(
          email.trim(),
          password
        );

        if (authError) {
          Alert.alert('Sign Up Error', authError.message);
          setIsCreatingAccount(false);
          return;
        }

        if (!authData.user) {
          Alert.alert('Sign Up Error', 'Failed to create account');
          setIsCreatingAccount(false);
          return;
        }

        userId = authData.user.id;
      }

      // Create user profile in public.users table
      // Retry up to 3 times if there's a foreign key constraint error
      let profileError = null;
      let retries = 3;

      while (retries > 0) {
        const result = await createUserProfile(
          userId,
          sex,
          dateOfBirth,
          heightInCm,
          weightInKg,
          firstName.trim(),
          lastName?.trim() || undefined,
          email.trim()
        );

        profileError = result.error;

        // If no error, break out of retry loop
        if (!profileError) {
          break;
        }

        // If it's a foreign key error, wait and retry
        if (profileError.message.includes('foreign key') || profileError.message.includes('users_id_fkey')) {
          retries--;
          if (retries > 0) {
            // Wait longer before retrying
            await new Promise(resolve => setTimeout(resolve, 1000));
            continue;
          }
        }

        // For other errors, don't retry
        break;
      }

      if (profileError) {
        Alert.alert(
          'Profile Error',
          profileError.message + '\n\nIf this persists, please check your Supabase database configuration.'
        );
        setIsCreatingAccount(false);
        return;
      }

      // Success - navigate to Home (paywall will show automatically if needed)
      setIsCreatingAccount(false);
      navigation.reset({
        index: 0,
        routes: [{ name: 'Home' }],
      });
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
      setIsCreatingAccount(false);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={6} totalSteps={7} />
        </View>
        
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
                Create your account
              </Animated.Text>
              
              <Animated.View 
                style={[
                  styles.inputsContainer,
                  {
                    opacity: inputsFade,
                  }
                ]}
              >
                <View style={styles.fullWidthInput}>
                  <View style={styles.inputWrapper}>
                    <Text style={styles.inputLabel}>Your email</Text>
                    <TextInput
                      style={[
                        styles.input,
                        errors.email && styles.inputError,
                      ]}
                      value={email}
                      onChangeText={setEmail}
                      placeholder="Your email"
                      placeholderTextColor="rgba(255, 255, 255, 0.4)"
                      keyboardType="email-address"
                      autoCapitalize="none"
                      textContentType="emailAddress"
                    />
                    {errors.email && (
                      <Text style={styles.errorText}>{errors.email}</Text>
                    )}
                  </View>
                </View>
                
                {!isAppleSignIn(signUpData) && (
                  <>
                    <View style={styles.fullWidthInput}>
                      <View style={styles.inputWrapper}>
                        <Text style={styles.inputLabel}>Password</Text>
                        <TextInput
                          style={[
                            styles.input,
                            errors.password && styles.inputError,
                          ]}
                          value={password}
                          onChangeText={setPassword}
                          placeholder="Enter your password"
                          placeholderTextColor="rgba(255, 255, 255, 0.4)"
                          secureTextEntry
                          textContentType="newPassword"
                        />
                        {errors.password && (
                          <Text style={styles.errorText}>{errors.password}</Text>
                        )}
                      </View>
                    </View>
                    
                    <View style={styles.fullWidthInput}>
                      <View style={styles.inputWrapper}>
                        <Text style={styles.inputLabel}>Confirm Password</Text>
                        <TextInput
                          style={[
                            styles.input,
                            errors.confirmPassword && styles.inputError,
                          ]}
                          value={confirmPassword}
                          onChangeText={setConfirmPassword}
                          placeholder="Confirm your password"
                          placeholderTextColor="rgba(255, 255, 255, 0.4)"
                          secureTextEntry
                          textContentType="password"
                        />
                        {errors.confirmPassword && (
                          <Text style={styles.errorText}>{errors.confirmPassword}</Text>
                        )}
                      </View>
                    </View>
                  </>
                )}
              </Animated.View>
            </View>
            
          </ScrollView>
        </KeyboardAvoidingView>

        {/* Bottom Navigation */}
        <View style={styles.bottomNavigation}>
          <View style={styles.bottomNavContent}>
            {/* Back Button */}
            <TouchableOpacity
              style={styles.backButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.goBack();
              }}
              activeOpacity={0.8}
            >
              <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M19 12H5M12 19l-7-7 7-7"
                  stroke="#000000"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
            </TouchableOpacity>

            {/* Next Button */}
            <TouchableOpacity
              style={styles.nextButton}
              onPress={handleContinue}
              disabled={isCreatingAccount}
              activeOpacity={0.9}
            >
              {isCreatingAccount ? (
                <ActivityIndicator size="small" color={Colors.white} />
              ) : (
                <>
                  <Text style={styles.nextButtonText}>Create</Text>
                  <Svg width={16} height={16} viewBox="0 0 24 24" fill="none">
                    <Path
                      d="M5 12h14M12 5l7 7-7 7"
                      stroke="#FFFFFF"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </Svg>
                </>
              )}
            </TouchableOpacity>
          </View>
        </View>
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
  progressBarContainer: {
    alignItems: 'center',
    paddingTop: Spacing.md,
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
    gap: 0,
  },
  fullWidthInput: {
    width: '100%',
    marginBottom: Spacing.md,
  },
  inputWrapper: {
    marginBottom: Spacing.md,
  },
  inputLabel: {
    fontSize: 14,
    fontFamily: 'ProductSans-Regular',
    color: 'rgba(255, 255, 255, 0.7)',
    marginBottom: 8,
  },
  input: {
    fontSize: 17,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 16,
    minHeight: 52,
  },
  inputError: {
    borderWidth: 1,
    borderColor: Colors.error,
  },
  errorText: {
    fontSize: 12,
    fontFamily: 'ProductSans-Regular',
    color: Colors.error,
    marginTop: 4,
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
  bottomNavigation: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: Spacing.lg,
    paddingBottom: 40,
    backgroundColor: 'transparent',
  },
  bottomNavContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 12,
  },
  backButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  nextButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    height: 48,
    borderRadius: 22,
    backgroundColor: Colors.primary,
    elevation: 16,
    shadowColor: '#BB3E4F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.6,
    shadowRadius: 16,
    gap: 8,
  },
  nextButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
});


