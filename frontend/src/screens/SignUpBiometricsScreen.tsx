import React, { useState, useRef } from 'react';
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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { Button } from '../components/Button';
import { ProgressBar } from '../components/ProgressBar';
import { WheelPicker } from '../components/WheelPicker';
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
  const [selectedAgeIndex, setSelectedAgeIndex] = useState(7); // Default 25
  const [selectedHeightIndex, setSelectedHeightIndex] = useState(70); // Default 170cm
  const [selectedWeightIndex, setSelectedWeightIndex] = useState(40); // Default 70kg
  const [loading, setLoading] = useState(false);
  
  const slideAnim = useRef(new Animated.Value(0)).current;

  const steps: Step[] = ['sex', 'age', 'height', 'weight'];
  const currentStepIndex = steps.indexOf(currentStep);

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

    if (currentStep !== 'weight') {
      const nextIndex = currentStepIndex + 1;
      setCurrentStep(steps[nextIndex]);
      animateToNext();
    } else {
      // Final step - create account
      setLoading(true);
      
      try {
        // Calculate date of birth from age
        const age = ages[selectedAgeIndex];
        const today = new Date();
        const birthYear = today.getFullYear() - age;
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
          // Create user profile in public.users table
          const { error: profileError } = await createUserProfile(
            authData.user.id,
            sex!,
            dateOfBirth,
            heights[selectedHeightIndex],
            weights[selectedWeightIndex]
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
            [{ text: 'OK', onPress: () => navigation.navigate('Welcome') }]
          );
        }
      } catch (error) {
        Alert.alert('Error', 'Something went wrong. Please try again.');
      }
      
      setLoading(false);
    }
  };

  const renderSexSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Your Sex</Text>
      <Text style={styles.stepSubtitle}>Select your biological sex</Text>
      
      <View style={styles.sexOptions}>
        <TouchableOpacity
          style={[
            styles.sexOption,
            sex === 'male' && styles.sexOptionSelected,
          ]}
          onPress={() => setSex('male')}
        >
          <Text style={styles.sexIcon}>♂</Text>
          <Text style={[styles.sexLabel, sex === 'male' && styles.sexLabelSelected]}>
            Male
          </Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={[
            styles.sexOption,
            sex === 'female' && styles.sexOptionSelected,
          ]}
          onPress={() => setSex('female')}
        >
          <Text style={styles.sexIcon}>♀</Text>
          <Text style={[styles.sexLabel, sex === 'female' && styles.sexLabelSelected]}>
            Female
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderAgeSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Your Age</Text>
      <Text style={styles.stepSubtitle}>How old are you?</Text>
      
      <View style={styles.pickerContainer}>
        <WheelPicker
          data={ages}
          selectedIndex={selectedAgeIndex}
          onSelect={setSelectedAgeIndex}
          suffix="years"
          isDark={true}
        />
      </View>
    </View>
  );

  const renderHeightSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Your Height</Text>
      <Text style={styles.stepSubtitle}>What's your height?</Text>
      
      <View style={styles.pickerContainer}>
        <WheelPicker
          data={heights}
          selectedIndex={selectedHeightIndex}
          onSelect={setSelectedHeightIndex}
          suffix="cm"
          isDark={true}
        />
      </View>
    </View>
  );

  const renderWeightSelection = () => (
    <View style={styles.stepContainer}>
      <Text style={styles.stepTitle}>Your Weight</Text>
      <Text style={styles.stepSubtitle}>What's your weight?</Text>
      
      <View style={styles.pickerContainer}>
        <WheelPicker
          data={weights}
          selectedIndex={selectedWeightIndex}
          onSelect={setSelectedWeightIndex}
          suffix="kg"
          isDark={true}
        />
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      {/* Background with blood tubes aesthetic */}
      <View style={styles.backgroundImage}>
        <View style={styles.tubesPattern}>
          {Array.from({ length: 12 }, (_, i) => (
            <View
              key={i}
              style={[
                styles.tube,
                {
                  transform: [{ rotate: '45deg' }],
                  top: 50 + (i % 4) * 120,
                  left: -20 + Math.floor(i / 4) * 140,
                },
              ]}
            >
              <View style={styles.tubeCap} />
              <View style={styles.tubeBody} />
            </View>
          ))}
        </View>
      </View>
      
      <SafeAreaView style={styles.safeArea}>
        <ProgressBar currentStep={currentStepIndex + 2} totalSteps={3} />
        
        <View style={styles.content}>
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
        </View>
        
        <View style={styles.buttonContainer}>
          <Button
            title={currentStep === 'weight' ? 'Create Account' : 'Continue'}
            onPress={handleContinue}
            variant="primary"
            loading={loading}
          />
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
  backgroundImage: {
    ...StyleSheet.absoluteFillObject,
  },
  tubesPattern: {
    flex: 1,
    opacity: 0.6,
  },
  tube: {
    position: 'absolute',
    width: 28,
    height: 100,
  },
  tubeCap: {
    width: 28,
    height: 16,
    backgroundColor: '#6B7FD7',
    borderTopLeftRadius: 6,
    borderTopRightRadius: 6,
  },
  tubeBody: {
    width: 28,
    height: 84,
    backgroundColor: '#8B1E3F',
    borderBottomLeftRadius: 14,
    borderBottomRightRadius: 14,
  },
  safeArea: {
    flex: 1,
  },
  content: {
    flex: 1,
  },
  slidingContainer: {
    flexDirection: 'row',
    width: SCREEN_WIDTH * 4,
    flex: 1,
  },
  slide: {
    width: SCREEN_WIDTH,
    paddingHorizontal: Spacing.lg,
  },
  stepContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  stepTitle: {
    fontSize: FontSize.xxl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  stepSubtitle: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    marginBottom: Spacing.xxl,
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
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
});

