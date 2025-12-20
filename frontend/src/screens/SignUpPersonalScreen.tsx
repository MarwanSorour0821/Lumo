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
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import GoogleSignInButton from '../components/GoogleSignInButton';
import AppleSignInButton from '../components/AppleSignInButton';
import Svg, { Path } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, AppleSignUpData, BiologicalSex } from '../types';
import { signInWithGoogle, signInWithApple, createUserProfile } from '../lib/supabase';

// Helper functions for conversions
const feetInchesToCm = (feet: number, inches: number): number => {
  return Math.round((feet * 30.48) + (inches * 2.54));
};

const lbsToKg = (lbs: number): number => {
  return Math.round(lbs * 0.453592);
};

 type SignUpPersonalScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpPersonal'>;
  route: RouteProp<RootStackParamList, 'SignUpPersonal'>;
};

export function SignUpPersonalScreen({ navigation, route }: SignUpPersonalScreenProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);
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

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const createAccountWithAllData = async (
    signUpData: AppleSignUpData,
    sex: BiologicalSex,
    age: string,
    height: string,
    heightFeet: string,
    heightInches: string,
    heightUnit: 'cm' | 'ft',
    weight: string,
    weightUnit: 'kg' | 'lbs'
  ) => {
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
        heightInCm = feetInchesToCm(feetNum, inchesNum);
      }

      // Convert weight to kg
      let weightInKg: number;
      if (weightUnit === 'kg') {
        weightInKg = parseFloat(weight);
      } else {
        weightInKg = lbsToKg(parseFloat(weight));
      }

      // Create user profile
      const result = await createUserProfile(
        signUpData.userId,
        sex,
        dateOfBirth,
        heightInCm,
        weightInKg,
        signUpData.firstName,
        signUpData.lastName,
        signUpData.email
      );

      if (result.error) {
        Alert.alert(
          'Profile Error', 
          result.error.message + '\n\nIf this persists, please check your Supabase database configuration.'
        );
        return false;
      }

      return true;
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
      return false;
    }
  };

  const handleContinue = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (validateForm()) {
      const { signUpData, sex, age, height, heightFeet, heightInches, heightUnit, weight, weightUnit } = route.params;
      navigation.navigate('SignUpCredentials', {
        signUpData,
        sex,
        age,
        height,
        heightFeet,
        heightInches,
        heightUnit,
        weight,
        weightUnit,
        firstName: firstName.trim(),
        lastName: lastName.trim() || undefined,
      });
    }
  };

  const handleGoogleSignIn = async () => {
    setIsGoogleLoading(true);
    try {
      const { data, error } = await signInWithGoogle();

      if (error) {
        if (error.message !== 'Sign in cancelled') {
          Alert.alert('Sign In Error', error.message);
        }
        setIsGoogleLoading(false);
        return;
      }

      if (data.user) {
        const providerFirst = data.user.firstName || firstName || undefined;
        const providerLast = data.user.lastName || lastName || undefined;

        const googleSignUpData: AppleSignUpData = {
          userId: data.user.id,
          email: data.user.email,
          firstName: providerFirst,
          lastName: providerLast,
          isAppleSignIn: true,
        };

        // Check if we have all the data already (sex, age, height, weight)
        const { sex, age, height, heightFeet, heightInches, heightUnit, weight, weightUnit } = route.params || {};
        
        if (sex && age && height && weight) {
          // We have all data, create account directly
          const success = await createAccountWithAllData(
            googleSignUpData,
            sex,
            age,
            height,
            heightFeet || '',
            heightInches || '',
            heightUnit || 'cm',
            weight,
            weightUnit || 'kg'
          );
          
          setIsGoogleLoading(false);
          
          if (success) {
            // Navigate to Home, then show paywall
            navigation.reset({
              index: 0,
              routes: [{ name: 'Home' }],
            });
            setTimeout(() => {
              navigation.navigate('PaywallMain');
            }, 500);
          }
        } else {
          // Missing data, continue to sex page
          setIsGoogleLoading(false);
          navigation.navigate('SignUpSex', { signUpData: googleSignUpData });
        }
      } else {
        Alert.alert('Sign In Error', 'Failed to get user information');
        setIsGoogleLoading(false);
      }
    } catch (error: any) {
      Alert.alert('Sign In Error', error.message || 'An unexpected error occurred');
      setIsGoogleLoading(false);
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
        const providerFirst = data.user.firstName || firstName || undefined;
        const providerLast = data.user.lastName || lastName || undefined;

        const appleSignUpData: AppleSignUpData = {
          userId: data.user.id,
          email: data.user.email,
          firstName: providerFirst,
          lastName: providerLast,
          isAppleSignIn: true,
        };

        // Check if we have all the data already (sex, age, height, weight)
        const { sex, age, height, heightFeet, heightInches, heightUnit, weight, weightUnit } = route.params || {};
        
        if (sex && age && height && weight) {
          // We have all data, create account directly
          const success = await createAccountWithAllData(
            appleSignUpData,
            sex,
            age,
            height,
            heightFeet || '',
            heightInches || '',
            heightUnit || 'cm',
            weight,
            weightUnit || 'kg'
          );
          
          setIsAppleLoading(false);
          
          if (success) {
            // Navigate to Home, then show paywall
            navigation.reset({
              index: 0,
              routes: [{ name: 'Home' }],
            });
            setTimeout(() => {
              navigation.navigate('PaywallMain');
            }, 500);
          }
        } else {
          // Missing data, continue to sex page
          setIsAppleLoading(false);
          navigation.navigate('SignUpSex', { signUpData: appleSignUpData });
        }
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
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={5} totalSteps={7} />
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
                  },
                ]}
              >
                What should we call you?
              </Animated.Text>

              <Animated.View
                style={[
                  styles.inputsContainer,
                  {
                    opacity: inputsFade,
                  },
                ]}
              >
                <View style={styles.halfInput}>
                  <View style={styles.inputWrapper}>
                    <Text style={styles.inputLabel}>First Name</Text>
                    <TextInput
                      style={[
                        styles.input,
                        errors.firstName && styles.inputError,
                      ]}
                      value={firstName}
                      onChangeText={setFirstName}
                      placeholder="John"
                      placeholderTextColor="rgba(255, 255, 255, 0.4)"
                      autoCapitalize="words"
                      textContentType="givenName"
                    />
                    {errors.firstName && (
                      <Text style={styles.errorText}>{errors.firstName}</Text>
                    )}
                  </View>
                </View>
                <View style={styles.halfInput}>
                  <View style={styles.inputWrapper}>
                    <Text style={styles.inputLabel}>Last Name (Optional)</Text>
                    <TextInput
                      style={styles.input}
                      value={lastName}
                      onChangeText={setLastName}
                      placeholder="Doe"
                      placeholderTextColor="rgba(255, 255, 255, 0.4)"
                      autoCapitalize="words"
                      textContentType="familyName"
                    />
                  </View>
                </View>
              </Animated.View>
            </View>

            {/* Apple Sign In Button */}
            <Animated.View
              style={[
                styles.socialButtonContainer,
                { opacity: buttonFade },
              ]}
            >
              <AppleSignInButton
                onPress={handleAppleSignIn}
                loading={isAppleLoading}
              />
            </Animated.View>

            {/* Google Sign In Button */}
            <Animated.View
              style={[
                styles.socialButtonContainer,
                { opacity: buttonFade },
              ]}
            >
              <GoogleSignInButton
                onPress={handleGoogleSignIn}
                loading={isGoogleLoading}
              />
            </Animated.View>

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
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                handleContinue();
              }}
              activeOpacity={0.9}
            >
              <Text style={styles.nextButtonText}>Next</Text>
              <Svg width={16} height={16} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M5 12h14M12 5l7 7-7 7"
                  stroke="#FFFFFF"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
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
  socialButtonContainer: {
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.sm,
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
