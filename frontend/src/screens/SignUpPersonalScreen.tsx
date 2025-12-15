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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Input } from '../components/Input';
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import GoogleSignInButton from '../components/GoogleSignInButton';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, AppleSignUpData } from '../types';
import { signInWithGoogle } from '../lib/supabase';

 type SignUpPersonalScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpPersonal'>;
};

export function SignUpPersonalScreen({ navigation }: SignUpPersonalScreenProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);
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

  const handleContinue = () => {
    if (validateForm()) {
      navigation.navigate('SignUpCredentials', {
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

        setIsGoogleLoading(false);
        navigation.navigate('SignUpSex', { signUpData: googleSignUpData });
      } else {
        Alert.alert('Sign In Error', 'Failed to get user information');
        setIsGoogleLoading(false);
      }
    } catch (error: any) {
      Alert.alert('Sign In Error', error.message || 'An unexpected error occurred');
      setIsGoogleLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />

      <SafeAreaView style={styles.safeArea}>
        <View style={styles.headerContainer}>
          <BackButton onPress={() => navigation.goBack()} theme="dark" />
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

            <Animated.View
              style={[
                styles.buttonContainer,
                {
                  opacity: buttonFade,
                },
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
  socialButtonContainer: {
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.sm,
  },
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
});
