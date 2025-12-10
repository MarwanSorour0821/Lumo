import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TouchableOpacity,
  Animated,
  Dimensions,
  Alert,
  KeyboardAvoidingView,
  Platform,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import * as Haptics from 'expo-haptics';
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import { Input } from '../components/Input';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, BiologicalSex } from '../types';
import { signUpWithEmail, createUserProfile } from '../lib/supabase';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

type SignUpBiometricsScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpBiometrics'>;
  route: RouteProp<RootStackParamList, 'SignUpBiometrics'>;
};

// Generate data arrays
const ages = Array.from({ length: 83 }, (_, i) => i + 18); // 18-100
const heights = Array.from({ length: 121 }, (_, i) => i + 100); // 100-220 cm
const weights = Array.from({ length: 201 }, (_, i) => i + 30); // 30-230 kg

type Step = 'sex' | 'age' | 'height' | 'weight';

export function SignUpBiometricsScreen({ navigation, route }: SignUpBiometricsScreenProps) {
  const { signUpData } = route.params;
  
  const [currentStep, setCurrentStep] = useState<Step>('sex');
  const [sex, setSex] = useState<BiologicalSex | null>(null);
  const [age, setAge] = useState('');
  const [ageFocused, setAgeFocused] = useState(false);
  const [height, setHeight] = useState('');
  const [heightFeet, setHeightFeet] = useState('');
  const [heightInches, setHeightInches] = useState('');
  const [heightUnit, setHeightUnit] = useState<'cm' | 'ft'>('cm');
  const [heightFocused, setHeightFocused] = useState(false);
  const [heightFeetFocused, setHeightFeetFocused] = useState(false);
  const [heightInchesFocused, setHeightInchesFocused] = useState(false);
  const [weight, setWeight] = useState('');
  const [weightUnit, setWeightUnit] = useState<'kg' | 'lbs'>('kg');
  const [weightFocused, setWeightFocused] = useState(false);
  const [loading, setLoading] = useState(false);
  const ageBorderAnim = useRef(new Animated.Value(0)).current;
  const heightBorderAnim = useRef(new Animated.Value(0)).current;
  const heightFeetBorderAnim = useRef(new Animated.Value(0)).current;
  const heightInchesBorderAnim = useRef(new Animated.Value(0)).current;
  const weightBorderAnim = useRef(new Animated.Value(0)).current;
  
  const slideAnim = useRef(new Animated.Value(0)).current;
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;
  const maleScale = useRef(new Animated.Value(1)).current;
  const femaleScale = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Reset and animate heading when step changes
    headingFade.setValue(0);
    contentFade.setValue(0);
    
    Animated.parallel([
      Animated.timing(headingFade, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.timing(contentFade, {
        toValue: 1,
        duration: 600,
        delay: 200,
        useNativeDriver: true,
      }),
    ]).start();
  }, [currentStep]);

  useEffect(() => {
    // Animate gender selection with scale animation
    Animated.parallel([
      Animated.spring(maleScale, {
        toValue: sex === 'male' ? 1.05 : 1,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }),
      Animated.spring(femaleScale, {
        toValue: sex === 'female' ? 1.05 : 1,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }),
    ]).start();
  }, [sex]);

  useEffect(() => {
    // Animate button on initial load
    Animated.timing(buttonFade, {
      toValue: 1,
      duration: 600,
      delay: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  useEffect(() => {
    Animated.timing(ageBorderAnim, {
      toValue: ageFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [ageFocused, ageBorderAnim]);

  useEffect(() => {
    Animated.timing(heightBorderAnim, {
      toValue: heightFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightFocused, heightBorderAnim]);

  useEffect(() => {
    Animated.timing(heightFeetBorderAnim, {
      toValue: heightFeetFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightFeetFocused, heightFeetBorderAnim]);

  useEffect(() => {
    Animated.timing(heightInchesBorderAnim, {
      toValue: heightInchesFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightInchesFocused, heightInchesBorderAnim]);

  useEffect(() => {
    Animated.timing(weightBorderAnim, {
      toValue: weightFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [weightFocused, weightBorderAnim]);

  const steps: Step[] = ['sex', 'age', 'height', 'weight'];
  const currentStepIndex = steps.indexOf(currentStep);

  // Conversion functions
  const feetInchesToCm = (feet: number, inches: number): number => {
    return Math.round((feet * 30.48) + (inches * 2.54));
  };

  const cmToFeetInches = (cm: number): { feet: number; inches: number } => {
    const totalInches = cm / 2.54;
    const feet = Math.floor(totalInches / 12);
    const inches = Math.round(totalInches % 12);
    return { feet, inches };
  };

  const lbsToKg = (lbs: number): number => {
    return Math.round(lbs * 0.453592);
  };

  const kgToLbs = (kg: number): number => {
    return Math.round(kg / 0.453592);
  };

  const animateToNext = () => {
    Animated.timing(slideAnim, {
      toValue: -SCREEN_WIDTH * (currentStepIndex + 1),
      duration: 300,
      useNativeDriver: true,
    }).start();
  };

  const handleContinue = async () => {
    if (currentStep === 'sex' && !sex) {
      Alert.alert('Please select your biological sex');
      return;
    }

    if (currentStep === 'age') {
      const ageNum = parseInt(age, 10);
      if (!age || isNaN(ageNum) || ageNum < 18 || ageNum > 100) {
        Alert.alert('Please enter a valid age between 18 and 100');
        return;
      }
    }

    if (currentStep === 'height') {
      if (heightUnit === 'cm') {
        const heightNum = parseInt(height, 10);
        if (!height || isNaN(heightNum) || heightNum < 100 || heightNum > 250) {
          Alert.alert('Please enter a valid height between 100 and 250 cm');
          return;
        }
      } else {
        const feetNum = parseInt(heightFeet, 10);
        const inchesNum = parseInt(heightInches, 10);
        if (!heightFeet || isNaN(feetNum) || feetNum < 3 || feetNum > 8) {
          Alert.alert('Please enter a valid height (feet between 3 and 8)');
          return;
        }
        if (!heightInches || isNaN(inchesNum) || inchesNum < 0 || inchesNum >= 12) {
          Alert.alert('Please enter a valid height (inches between 0 and 11)');
          return;
        }
      }
    }

    if (currentStep === 'weight') {
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
    }

    if (currentStep !== 'weight') {
      const nextIndex = currentStepIndex + 1;
      setCurrentStep(steps[nextIndex]);
      animateToNext();
    } else {
      // Final step - create account
      setLoading(true);
      
      try {
        // Calculate date of birth from age
        const ageNum = parseInt(age, 10);
        const today = new Date();
        const birthYear = today.getFullYear() - ageNum;
        const dateOfBirth = new Date(birthYear, today.getMonth(), today.getDate());
        
        // Sign up with Supabase Auth
        const { data: authData, error: authError } = await signUpWithEmail(
          signUpData.email,
          signUpData.password
        );
        
        if (authError) {
          Alert.alert('Sign Up Error', authError.message);
          setLoading(false);
          return;
        }
        
        if (authData.user) {
          // Convert height to cm
          let heightInCm: number;
          if (heightUnit === 'cm') {
            heightInCm = parseInt(height, 10);
          } else {
            const feetNum = parseInt(heightFeet, 10);
            const inchesNum = parseInt(heightInches, 10);
            heightInCm = feetInchesToCm(feetNum, inchesNum);
          }

          // Convert weight to kg
          let weightInKg: number;
          if (weightUnit === 'kg') {
            weightInKg = parseFloat(weight);
          } else {
            weightInKg = lbsToKg(parseFloat(weight));
          }

          // Create user profile in public.users table
          const { error: profileError } = await createUserProfile(
            authData.user.id,
            sex!,
            dateOfBirth,
            heightInCm,
            weightInKg
          );
          
          if (profileError) {
            Alert.alert('Profile Error', profileError.message);
            setLoading(false);
            return;
          }
          
          // Success - navigate to home or verification screen
          Alert.alert(
            'Success!',
            'Your account has been created. Please check your email to verify your account.',
            [{ text: 'OK', onPress: () => navigation.navigate('Onboarding') }]
          );
        }
      } catch (error) {
        Alert.alert('Error', 'Something went wrong. Please try again.');
      }
      
      setLoading(false);
    }
  };

  const getHeadingText = () => {
    switch (currentStep) {
      case 'sex':
        return 'Your Sex';
      case 'age':
        return 'Your Age';
      case 'height':
        return 'Your Height';
      case 'weight':
        return 'Your Weight';
      default:
        return 'Your Sex';
    }
  };

  const getSubtitleText = () => {
    switch (currentStep) {
      case 'sex':
        return 'Select your biological sex';
      case 'age':
        return 'How old are you?';
      case 'height':
        return "What's your height?";
      case 'weight':
        return "What's your weight?";
      default:
        return 'Select your biological sex';
    }
  };

  const renderSexSelection = () => {
    return (
      <View style={styles.stepContainer}>
        <View style={styles.sexOptions}>
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              setSex('male');
            }}
          >
            <Animated.View
              style={[
                styles.sexOption,
                sex === 'male' && styles.sexOptionSelected,
                {
                  transform: [{ scale: maleScale }],
                },
              ]}
            >
              <Text style={styles.sexIcon}>♂</Text>
              <Text
                style={[
                  styles.sexLabel,
                  sex === 'male' && styles.sexLabelSelected,
                ]}
              >
                Male
              </Text>
            </Animated.View>
          </TouchableOpacity>
          
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              setSex('female');
            }}
          >
            <Animated.View
              style={[
                styles.sexOption,
                sex === 'female' && styles.sexOptionSelected,
                {
                  transform: [{ scale: femaleScale }],
                },
              ]}
            >
              <Text style={styles.sexIcon}>♀</Text>
              <Text
                style={[
                  styles.sexLabel,
                  sex === 'female' && styles.sexLabelSelected,
                ]}
              >
                Female
              </Text>
            </Animated.View>
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  const renderAgeSelection = () => {
    const borderOpacity = ageBorderAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    });

    return (
      <View style={styles.stepContainer}>
        <View style={styles.ageInputContainer}>
          <View style={{ position: 'relative', width: 200 }}>
            <TextInput
              style={styles.ageTextInput}
              value={age}
              onChangeText={setAge}
              placeholder="24"
              placeholderTextColor={Colors.dark.textSecondary}
              keyboardType="numeric"
              onFocus={() => setAgeFocused(true)}
              onBlur={() => setAgeFocused(false)}
            />
            <View style={[styles.ageBorder, { backgroundColor: Colors.dark.border }]} />
            <Animated.View
              style={[
                styles.ageBorder,
                styles.ageBorderAnimated,
                {
                  backgroundColor: Colors.primary,
                  opacity: borderOpacity,
                },
              ]}
            />
          </View>
        </View>
      </View>
    );
  };

  const renderHeightSelection = () => {
    const borderOpacity = heightBorderAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    });
    const feetBorderOpacity = heightFeetBorderAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    });
    const inchesBorderOpacity = heightInchesBorderAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    });

    return (
      <View style={styles.stepContainer}>
        {/* Unit Toggle */}
        <View style={styles.unitToggleContainer}>
          <TouchableOpacity
            style={[
              styles.unitToggle,
              heightUnit === 'cm' && styles.unitToggleActive,
            ]}
            onPress={() => setHeightUnit('cm')}
          >
            <Text
              style={[
                styles.unitToggleText,
                heightUnit === 'cm' && styles.unitToggleTextActive,
              ]}
            >
              cm
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.unitToggle,
              heightUnit === 'ft' && styles.unitToggleActive,
            ]}
            onPress={() => setHeightUnit('ft')}
          >
            <Text
              style={[
                styles.unitToggleText,
                heightUnit === 'ft' && styles.unitToggleTextActive,
              ]}
            >
              ft/in
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.ageInputContainer}>
          {heightUnit === 'cm' ? (
            <View style={{ position: 'relative', width: 200 }}>
              <TextInput
                style={styles.ageTextInput}
                value={height}
                onChangeText={setHeight}
                placeholder="170"
                placeholderTextColor={Colors.dark.textSecondary}
                keyboardType="numeric"
                onFocus={() => setHeightFocused(true)}
                onBlur={() => setHeightFocused(false)}
              />
              <View style={[styles.ageBorder, { backgroundColor: Colors.dark.border }]} />
              <Animated.View
                style={[
                  styles.ageBorder,
                  styles.ageBorderAnimated,
                  {
                    backgroundColor: Colors.primary,
                    opacity: borderOpacity,
                  },
                ]}
              />
            </View>
          ) : (
            <View style={styles.feetInchesContainer}>
              <View style={styles.feetInchesInputWrapper}>
                <Text style={styles.unitLabelLeft}>ft</Text>
                <View style={{ position: 'relative', flex: 1, marginLeft: Spacing.sm }}>
                  <TextInput
                    style={styles.feetInchesInput}
                    value={heightFeet}
                    onChangeText={setHeightFeet}
                    placeholder="5"
                    placeholderTextColor={Colors.dark.textSecondary}
                    keyboardType="numeric"
                    onFocus={() => setHeightFeetFocused(true)}
                    onBlur={() => setHeightFeetFocused(false)}
                  />
                  <View style={[styles.ageBorder, { backgroundColor: Colors.dark.border }]} />
                  <Animated.View
                    style={[
                      styles.ageBorder,
                      styles.ageBorderAnimated,
                      {
                        backgroundColor: Colors.primary,
                        opacity: feetBorderOpacity,
                      },
                    ]}
                  />
                </View>
              </View>
              <View style={[styles.feetInchesInputWrapper, { marginLeft: Spacing.lg }]}>
                <Text style={styles.unitLabelLeft}>in</Text>
                <View style={{ position: 'relative', flex: 1, marginLeft: Spacing.sm }}>
                  <TextInput
                    style={styles.feetInchesInput}
                    value={heightInches}
                    onChangeText={setHeightInches}
                    placeholder="10"
                    placeholderTextColor={Colors.dark.textSecondary}
                    keyboardType="numeric"
                    onFocus={() => setHeightInchesFocused(true)}
                    onBlur={() => setHeightInchesFocused(false)}
                  />
                  <View style={[styles.ageBorder, { backgroundColor: Colors.dark.border }]} />
                  <Animated.View
                    style={[
                      styles.ageBorder,
                      styles.ageBorderAnimated,
                      {
                        backgroundColor: Colors.primary,
                        opacity: inchesBorderOpacity,
                      },
                    ]}
                  />
                </View>
              </View>
            </View>
          )}
        </View>
      </View>
    );
  };

  const renderWeightSelection = () => {
    const borderOpacity = weightBorderAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [0, 1],
    });

    return (
      <View style={styles.stepContainer}>
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

        <View style={styles.ageInputContainer}>
          <View style={{ position: 'relative', width: 200 }}>
            <TextInput
              style={styles.ageTextInput}
              value={weight}
              onChangeText={setWeight}
              placeholder={weightUnit === 'kg' ? '70' : '154'}
              placeholderTextColor={Colors.dark.textSecondary}
              keyboardType="numeric"
              onFocus={() => setWeightFocused(true)}
              onBlur={() => setWeightFocused(false)}
            />
            <View style={[styles.ageBorder, { backgroundColor: Colors.dark.border }]} />
            <Animated.View
              style={[
                styles.ageBorder,
                styles.ageBorderAnimated,
                {
                  backgroundColor: Colors.primary,
                  opacity: borderOpacity,
                },
              ]}
            />
          </View>
        </View>
      </View>
    );
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
        <ProgressBar currentStep={currentStepIndex + 3} totalSteps={4} />
        
        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        >
          {(currentStep === 'sex' || currentStep === 'age' || currentStep === 'height' || currentStep === 'weight') ? (
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
                  {getHeadingText()}
                </Animated.Text>
                
                <Animated.Text 
                  style={[
                    styles.subtitle,
                    {
                      opacity: headingFade,
                    }
                  ]}
                >
                  {getSubtitleText()}
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
                <Animated.View
                  style={[
                    styles.slidingContainer,
                    { transform: [{ translateX: slideAnim }] },
                  ]}
                >
                  <View style={styles.slide}>{renderSexSelection()}</View>
                  <View style={styles.slide}>{renderAgeSelection()}</View>
                  <View style={styles.slide}>{renderHeightSelection()}</View>
                  <View style={styles.slide}>{renderWeightSelection()}</View>
                </Animated.View>
              </Animated.View>
            </ScrollView>
          ) : (
            <View style={styles.scrollView}>
              <View style={styles.headingContainer}>
                <Animated.Text 
                  style={[
                    styles.heading,
                    {
                      opacity: headingFade,
                    }
                  ]}
                >
                  {getHeadingText()}
                </Animated.Text>
                
                <Animated.Text 
                  style={[
                    styles.subtitle,
                    {
                      opacity: headingFade,
                    }
                  ]}
                >
                  {getSubtitleText()}
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
                <Animated.View
                  style={[
                    styles.slidingContainer,
                    { transform: [{ translateX: slideAnim }] },
                  ]}
                >
                  <View style={styles.slide}>{renderSexSelection()}</View>
                  <View style={styles.slide}>{renderAgeSelection()}</View>
                  <View style={styles.slide}>{renderHeightSelection()}</View>
                  <View style={styles.slide}>{renderWeightSelection()}</View>
                </Animated.View>
              </Animated.View>
            </View>
          )}
          
          <Animated.View 
            style={[
              styles.buttonContainer,
              {
                opacity: buttonFade,
              }
            ]}
          >
            <PrimaryButton
              text={currentStep === 'weight' ? 'Create Account' : 'Continue'}
              onPress={loading ? undefined : handleContinue}
              theme="dark"
            />
          </Animated.View>
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
    flexGrow: 1,
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
    marginBottom: 8,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
  },
  subtitle: {
    fontSize: 16,
    lineHeight: 24,
    marginBottom: 32,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  content: {
    minHeight: 400,
  },
  slidingContainer: {
    flexDirection: 'row',
    width: SCREEN_WIDTH * 4,
  },
  slide: {
    width: SCREEN_WIDTH,
    paddingHorizontal: Spacing.lg,
  },
  stepContainer: {
    minHeight: 400,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sexOptions: {
    flexDirection: 'row',
    gap: Spacing.lg,
  },
  sexOption: {
    width: 120,
    height: 140,
    borderRadius: BorderRadius.lg,
    borderWidth: 2,
    borderColor: Colors.dark.border,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
  },
  sexOptionSelected: {
    borderColor: Colors.primary,
    backgroundColor: 'rgba(176, 19, 40, 0.15)',
  },
  sexIcon: {
    fontSize: 48,
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  sexLabel: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontWeight: FontWeight.medium,
  },
  sexLabelSelected: {
    color: Colors.primary,
  },
  pickerContainer: {
    width: '100%',
    alignItems: 'center',
  },
  ageInputContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  ageTextInput: {
    width: 200,
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'center',
    paddingVertical: Spacing.xs,
    paddingBottom: 4,
  },
  ageBorder: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 1,
  },
  ageBorderAnimated: {
    height: 1,
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
  feetInchesContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    width: '100%',
    paddingHorizontal: Spacing.xl,
    alignSelf: 'flex-start',
  },
  feetInchesInputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  feetInchesInput: {
    flex: 1,
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'left',
    paddingVertical: Spacing.xs,
    paddingBottom: 4,
  },
  unitLabelLeft: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
    minWidth: 30,
  },
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
});

