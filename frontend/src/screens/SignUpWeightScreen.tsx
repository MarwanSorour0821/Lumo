import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Animated,
  Alert,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, BiologicalSex, SignUpData, AppleSignUpData } from '../types';
import { signUpWithEmail, createUserProfile } from '../lib/supabase';

// Helper to check if signUpData is from Apple Sign In
const isAppleSignIn = (data: SignUpData | AppleSignUpData): data is AppleSignUpData => {
  return 'isAppleSignIn' in data && data.isAppleSignIn === true;
};

type SignUpWeightScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpWeight'>;
  route: RouteProp<RootStackParamList, 'SignUpWeight'>;
};

export function SignUpWeightScreen({ navigation, route }: SignUpWeightScreenProps) {
  const { signUpData, sex, age, height, heightFeet, heightInches, heightUnit } = route.params;
  
  const [weight, setWeight] = useState('');
  const [weightUnit, setWeightUnit] = useState<'kg' | 'lbs'>('kg');
  const [weightFocused, setWeightFocused] = useState(false);
  const [loading, setLoading] = useState(false);
  const weightBorderAnim = useRef(new Animated.Value(0)).current;
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(headingFade, {
        toValue: 1,
        duration: 400,
        useNativeDriver: true,
      }),
      Animated.timing(contentFade, {
        toValue: 1,
        duration: 400,
        delay: 200,
        useNativeDriver: true,
      }),
      Animated.timing(buttonFade, {
        toValue: 1,
        duration: 400,
        delay: 400,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  useEffect(() => {
    Animated.timing(weightBorderAnim, {
      toValue: weightFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [weightFocused, weightBorderAnim]);

  // Conversion functions
  const feetInchesToCm = (feet: number, inches: number): number => {
    return Math.round((feet * 30.48) + (inches * 2.54));
  };

  const lbsToKg = (lbs: number): number => {
    return Math.round(lbs * 0.453592);
  };

  const handleContinue = async () => {
    const weightNum = parseFloat(weight);
    if (!weight || isNaN(weightNum)) {
      Alert.alert('Please enter a valid weight');
      return;
    }
    if (weightUnit === 'kg') {
      if (weightNum < 30 || weightNum > 300) {
        Alert.alert('Please enter a valid weight between 30 and 300 kg');
        return;
      }
    } else {
      if (weightNum < 66 || weightNum > 660) {
        Alert.alert('Please enter a valid weight between 66 and 660 lbs');
        return;
      }
    }

    setLoading(true);
    
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

      let userId: string;

      // Check if this is an Apple Sign In user (already authenticated)
      if (isAppleSignIn(signUpData)) {
        // User is already authenticated via Apple, use their ID directly
        userId = signUpData.userId;
      } else {
        // Regular sign up with email/password
        const { data: authData, error: authError } = await signUpWithEmail(
          signUpData.email,
          signUpData.password
        );
        
        if (authError) {
          Alert.alert('Sign Up Error', authError.message);
          setLoading(false);
          return;
        }
        
        if (!authData.user) {
          Alert.alert('Sign Up Error', 'Failed to create account');
          setLoading(false);
          return;
        }
        
        userId = authData.user.id;
      }

      // Create user profile in public.users table
      // Retry up to 3 times if there's a foreign key constraint error
      let profileError = null;
      let retries = 3;
      
      // Extract user information from signUpData
      let firstName: string | undefined;
      let lastName: string | undefined;
      let email: string | undefined;
      
      if (isAppleSignIn(signUpData)) {
        firstName = signUpData.firstName;
        lastName = signUpData.lastName;
        email = signUpData.email;
      } else {
        // Regular signup - extract from SignUpData
        firstName = signUpData.firstName;
        lastName = signUpData.lastName;
        email = signUpData.email;
      }

      console.log('SignUpWeightScreen - Full signUpData:', signUpData);
      console.log('SignUpWeightScreen - Extracted user info:', {
        firstName,
        lastName,
        email,
        isAppleSignIn: isAppleSignIn(signUpData),
        signUpDataType: isAppleSignIn(signUpData) ? 'AppleSignUpData' : 'SignUpData'
      });

      // Validate that we have the required data
      if (!firstName || !lastName || !email) {
        console.error('SignUpWeightScreen - Missing user information:', {
          firstName: firstName || 'MISSING',
          lastName: lastName || 'MISSING',
          email: email || 'MISSING',
          signUpDataKeys: Object.keys(signUpData)
        });
        Alert.alert(
          'Error',
          'Missing user information. Please go back and ensure all fields are filled.'
        );
        setLoading(false);
        return;
      }
      
      while (retries > 0) {
        const result = await createUserProfile(
          userId,
          sex,
          dateOfBirth,
          heightInCm,
          weightInKg,
          firstName,
          lastName,
          email
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
        setLoading(false);
        return;
      }

      // Success - hide loading and navigate to Home
      setLoading(false);
      navigation.reset({
        index: 0,
        routes: [{ name: 'Home' }],
      });
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
      setLoading(false);
    }
  };

  const borderOpacity = weightBorderAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });

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
        <ProgressBar currentStep={6} totalSteps={7} />
        
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
                Your Weight
              </Animated.Text>
              
              <Animated.Text 
                style={[
                  styles.subtitle,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                What's your weight?
              </Animated.Text>
            </View>

            <Animated.View
              style={[
                styles.content,
                {
                  opacity: contentFade,
                }
              ]}
            >
              {/* Unit Toggle */}
              <View style={styles.unitToggleContainer}>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    weightUnit === 'kg' && styles.unitToggleActive,
                  ]}
                  onPress={() => setWeightUnit('kg')}
                >
                  <Text
                    style={[
                      styles.unitToggleText,
                      weightUnit === 'kg' && styles.unitToggleTextActive,
                    ]}
                  >
                    kg
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    weightUnit === 'lbs' && styles.unitToggleActive,
                  ]}
                  onPress={() => setWeightUnit('lbs')}
                >
                  <Text
                    style={[
                      styles.unitToggleText,
                      weightUnit === 'lbs' && styles.unitToggleTextActive,
                    ]}
                  >
                    lbs
                  </Text>
                </TouchableOpacity>
              </View>

              <View style={styles.inputContainer}>
                <View style={{ position: 'relative', width: 200 }}>
                  <TextInput
                    style={styles.textInput}
                    value={weight}
                    onChangeText={setWeight}
                    placeholder={weightUnit === 'kg' ? '70' : '154'}
                    placeholderTextColor={Colors.dark.textSecondary}
                    keyboardType="numeric"
                    onFocus={() => setWeightFocused(true)}
                    onBlur={() => setWeightFocused(false)}
                  />
                  <View style={[styles.border, { backgroundColor: Colors.dark.border }]} />
                  <Animated.View
                    style={[
                      styles.border,
                      styles.borderAnimated,
                      {
                        backgroundColor: Colors.primary,
                        opacity: borderOpacity,
                      },
                    ]}
                  />
                </View>
              </View>
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
                text="Create Account"
                onPress={handleContinue}
                disabled={loading}
                theme="dark"
              />
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>

      {/* Loading Overlay */}
      <Modal
        transparent={true}
        visible={loading}
        animationType="fade"
      >
        <View style={styles.loadingOverlay}>
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color={Colors.primary} />
            <Text style={styles.loadingText}>Creating your account...</Text>
          </View>
        </View>
      </Modal>
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
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: Spacing.lg,
  },
  headingContainer: {
    marginTop: Spacing.xl,
    marginBottom: Spacing.xxl,
  },
  heading: {
    fontSize: 40,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    marginTop: Spacing.xs,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
  },
  unitToggleContainer: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.xl,
    justifyContent: 'center',
  },
  unitToggle: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: 'transparent',
  },
  unitToggleActive: {
    borderColor: Colors.primary,
    backgroundColor: 'rgba(176, 19, 40, 0.15)',
  },
  unitToggleText: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  unitToggleTextActive: {
    color: Colors.primary,
    fontFamily: 'ProductSans-Bold',
  },
  inputContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  textInput: {
    width: 200,
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'center',
    paddingVertical: Spacing.xs,
    paddingBottom: 4,
  },
  border: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 1,
  },
  borderAnimated: {
    height: 1,
  },
  buttonContainer: {
    paddingBottom: Spacing.lg,
  },
  loadingOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingContainer: {
    backgroundColor: Colors.dark.background,
    borderRadius: BorderRadius.lg,
    padding: Spacing.xl,
    alignItems: 'center',
    minWidth: 200,
  },
  loadingText: {
    marginTop: Spacing.md,
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
});

