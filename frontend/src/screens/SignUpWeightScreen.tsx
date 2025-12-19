import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TouchableOpacity,
  Animated,
  Alert,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Modal,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { RulerPicker } from 'react-native-ruler-picker';
import Svg, { Path } from 'react-native-svg';
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
  
  // Initialize with default values based on unit
  const [weightUnit, setWeightUnit] = useState<'kg' | 'lbs'>('lbs');
  const [weight, setWeight] = useState<number>(weightUnit === 'kg' ? 70 : 154);
  const [loading, setLoading] = useState(false);
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;
  const previousWeightRef = useRef<number>(weightUnit === 'kg' ? 70 : 154);
  
  const screenWidth = Dimensions.get('window').width;

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

  // Handle unit conversion when switching units
  const prevUnitRef = useRef(weightUnit);
  useEffect(() => {
    if (prevUnitRef.current !== weightUnit) {
      const currentWeight = weight;
      if (weightUnit === 'kg') {
        // Convert from lbs to kg
        const newWeight = Math.round(currentWeight * 0.453592);
        if (newWeight >= 30 && newWeight <= 300) {
          setWeight(newWeight);
        } else {
          setWeight(70); // Default kg value
        }
      } else {
        // Convert from kg to lbs
        const newWeight = Math.round(currentWeight / 0.453592);
        if (newWeight >= 66 && newWeight <= 660) {
          setWeight(newWeight);
        } else {
          setWeight(154); // Default lbs value
        }
      }
      prevUnitRef.current = weightUnit;
    }
  }, [weightUnit, weight]);

  // Conversion functions
  const feetInchesToCm = (feet: number, inches: number): number => {
    return Math.round((feet * 30.48) + (inches * 2.54));
  };

  const lbsToKg = (lbs: number): number => {
    return Math.round(lbs * 0.453592);
  };

  const handleContinue = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const weightNum = weight;
    if (!weightNum || isNaN(weightNum)) {
      Alert.alert('Please select a valid weight');
      return;
    }
    if (weightUnit === 'kg') {
      if (weightNum < 30 || weightNum > 300) {
        Alert.alert('Please select a valid weight between 30 and 300 kg');
        return;
      }
    } else {
      if (weightNum < 66 || weightNum > 660) {
        Alert.alert('Please select a valid weight between 66 and 660 lbs');
        return;
      }
    }

    // Convert weight to kg for storage
    const weightInKg = weightUnit === 'kg' ? weight : lbsToKg(weight);
    
    navigation.navigate('SignUpPersonal', {
      signUpData,
      sex,
      age,
      height,
      heightFeet,
      heightInches,
      heightUnit,
      weight: weightInKg.toString(),
      weightUnit: 'kg',
    });
  };

  const handleContinueOld = async () => {
    const weightNum = weight;
    if (!weightNum || isNaN(weightNum)) {
      Alert.alert('Please select a valid weight');
      return;
    }
    if (weightUnit === 'kg') {
      if (weightNum < 30 || weightNum > 300) {
        Alert.alert('Please select a valid weight between 30 and 300 kg');
        return;
      }
    } else {
      if (weightNum < 66 || weightNum > 660) {
        Alert.alert('Please select a valid weight between 66 and 660 lbs');
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
        weightInKg = weight;
      } else {
        weightInKg = lbsToKg(weight);
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

      // Validate that we have the required data (last name optional)
      if (!firstName || !email) {
        console.error('SignUpWeightScreen - Missing required user information:', {
          firstName: firstName || 'MISSING',
          lastName: lastName || 'MISSING (allowed)',
          email: email || 'MISSING',
          signUpDataKeys: Object.keys(signUpData)
        });
        Alert.alert(
          'Error',
          'Missing required user information. Please go back and ensure your name and email are filled.'
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

      // Success - hide loading and navigate to Paywall Learn More (first screen)
      setLoading(false);
      navigation.reset({
        index: 0,
        routes: [{ name: 'PaywallLearnMore' }],
      });
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An unexpected error occurred');
      setLoading(false);
    }
  };

  // Ruler picker configuration
  const rulerConfig = {
    min: weightUnit === 'kg' ? 30 : 66,
    max: weightUnit === 'kg' ? 300 : 660,
    step: weightUnit === 'kg' ? 1 : 1,
    unit: weightUnit === 'kg' ? 'kg' : 'lbs',
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={4} totalSteps={7} />
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
            contentInsetAdjustmentBehavior="never"
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
                What is your weight?
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
              <View style={styles.contentWrapper}>
              {/* Unit Toggle */}
              <View style={styles.unitToggleContainer}>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    weightUnit === 'kg' && styles.unitToggleActive,
                  ]}
                  onPress={() => setWeightUnit('kg')}
                >
                  {weightUnit === 'kg' ? (
                    <View style={styles.unitToggleIcon}>
                      <Text style={styles.unitToggleCheckmark}>✓</Text>
                    </View>
                  ) : (
                    <View style={styles.unitToggleDot} />
                  )}
                  <Text
                    style={[
                      styles.unitToggleText,
                      weightUnit === 'kg' && styles.unitToggleTextActive,
                    ]}
                  >
                    Kgs
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    weightUnit === 'lbs' && styles.unitToggleActive,
                  ]}
                  onPress={() => setWeightUnit('lbs')}
                >
                  {weightUnit === 'lbs' ? (
                    <View style={styles.unitToggleIcon}>
                      <Text style={styles.unitToggleCheckmark}>✓</Text>
                    </View>
                  ) : (
                    <View style={styles.unitToggleDot} />
                  )}
                  <Text
                    style={[
                      styles.unitToggleText,
                      weightUnit === 'lbs' && styles.unitToggleTextActive,
                    ]}
                  >
                    Ibs
                  </Text>
                </TouchableOpacity>
              </View>

              {/* Weight Display */}
              <View style={styles.weightDisplayContainer}>
                <Text style={styles.weightDisplay}>
                  {Math.round(weight)} {weightUnit === 'kg' ? 'kg' : 'lbs'}
                </Text>
              </View>

              {/* Ruler Picker */}
              <View style={styles.rulerContainer}>
                {/* Left fade gradient */}
                <LinearGradient
                  colors={[Colors.dark.background, 'transparent']}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 0 }}
                  style={styles.fadeGradientLeft}
                  pointerEvents="none"
                />
                <RulerPicker
                  min={rulerConfig.min}
                  max={rulerConfig.max}
                  step={rulerConfig.step}
                  initialValue={weight}
                  onValueChange={(value: string) => {
                    const newWeight = Math.round(parseFloat(value));
                    if (newWeight !== previousWeightRef.current) {
                      previousWeightRef.current = newWeight;
                      setWeight(newWeight);
                      // Trigger haptic feedback when value changes
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    }
                  }}
                  onValueChangeEnd={(value: string) => {
                    const newWeight = Math.round(parseFloat(value));
                    setWeight(newWeight);
                    previousWeightRef.current = newWeight;
                  }}
                  unit={rulerConfig.unit}
                  height={180}
                  width={screenWidth}
                  indicatorColor={Colors.primary}
                  indicatorHeight={80}
                  gapBetweenSteps={10}
                  shortStepHeight={30}
                  longStepHeight={90}
                  stepWidth={1.5}
                  valueTextStyle={{
                    color: Colors.white,
                    fontSize: 16,
                  }}
                  unitTextStyle={{
                    color: Colors.white,
                    fontSize: 16,
                  }}
                  fractionDigits={0}
                />
                {/* Right fade gradient */}
                <LinearGradient
                  colors={['transparent', Colors.dark.background]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 0 }}
                  style={styles.fadeGradientRight}
                  pointerEvents="none"
                />
              </View>
              </View>
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
              style={[styles.nextButton, loading && styles.nextButtonDisabled]}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                handleContinue();
              }}
              disabled={loading}
              activeOpacity={0.9}
            >
              {loading ? (
                <ActivityIndicator size="small" color={Colors.white} />
              ) : (
                <>
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
                </>
              )}
            </TouchableOpacity>
          </View>
        </View>
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
    paddingVertical: Spacing.xl,
  },
  contentWrapper: {
    width: '100%',
  },
  unitToggleContainer: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.xl,
    justifyContent: 'center',
  },
  unitToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: Colors.dark.surface,
    minWidth: 100,
    justifyContent: 'center',
    gap: Spacing.xs,
  },
  unitToggleActive: {
    borderColor: Colors.primary,
    backgroundColor: Colors.primary,
  },
  unitToggleIcon: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: Colors.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  unitToggleCheckmark: {
    color: Colors.primary,
    fontSize: 12,
    fontWeight: 'bold',
  },
  unitToggleDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.dark.textSecondary,
  },
  unitToggleText: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  unitToggleTextActive: {
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
  },
  weightDisplayContainer: {
    alignItems: 'center',
    marginBottom: Spacing.xl,
    marginTop: Spacing.lg,
  },
  weightDisplay: {
    fontSize: 48,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    textAlign: 'center',
  },
  rulerContainer: {
    width: Dimensions.get('window').width,
    alignSelf: 'stretch',
    marginTop: Spacing.lg,
    marginBottom: Spacing.xl,
    marginLeft: -Spacing.lg, // Negative margin to extend beyond left padding
    marginRight: -Spacing.lg, // Negative margin to extend beyond right padding
    overflow: 'visible',
    position: 'relative',
  },
  fadeGradientLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: 60,
    zIndex: 1,
  },
  fadeGradientRight: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 60,
    zIndex: 1,
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
  nextButtonDisabled: {
    opacity: 0.5,
  },
  nextButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
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


