import React, { useEffect, useRef, useState } from 'react';
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
import BackButton from '../../components/BackButton';
import PrimaryButton from '../../components/PrimaryButton';
import { Input } from '../components/Input';
import { Colors, Spacing, FontSize } from '../constants/theme';
import { RootStackParamList } from '../types';
import { signInWithEmail } from '../lib/supabase';

type LoginScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Login'>;
};

export function LoginScreen({ navigation }: LoginScreenProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);

  const headingFade = useRef(new Animated.Value(0)).current;
  const inputsFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(headingFade, {
      toValue: 1,
      duration: 700,
      useNativeDriver: true,
    }).start();

    Animated.timing(inputsFade, {
      toValue: 1,
      duration: 600,
      delay: 150,
      useNativeDriver: true,
    }).start();

    Animated.timing(buttonFade, {
      toValue: 1,
      duration: 600,
      delay: 300,
      useNativeDriver: true,
    }).start();
  }, [headingFade, inputsFade, buttonFade]);

  const validate = () => {
    const nextErrors: Record<string, string> = {};
    if (!email.trim()) {
      nextErrors.email = 'Email is required';
    }
    if (!password.trim()) {
      nextErrors.password = 'Password is required';
    }
    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleSignIn = async () => {
    if (!validate()) return;
    setLoading(true);
    const { data, error } = await signInWithEmail(email.trim(), password);

    if (error) {
      Alert.alert('Sign In Error', error.message);
      setLoading(false);
      return;
    }

    if (data.user) {
      setLoading(false);
      // Navigate to Home screen
      navigation.reset({
        index: 0,
        routes: [{ name: 'Home' }],
      });
    } else {
      setLoading(false);
      Alert.alert('Sign In Error', 'Unable to sign in. Please try again.');
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <BackButton onPress={() => navigation.goBack()} theme="dark" />
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
            <Animated.Text style={[styles.heading, { opacity: headingFade }]}>
              Welcome back
            </Animated.Text>

            <Animated.View style={[styles.inputsContainer, { opacity: inputsFade }]}>
              <Input
                label="Email"
                value={email}
                onChangeText={setEmail}
                placeholder="you@example.com"
                keyboardType="email-address"
                autoCapitalize="none"
                error={errors.email}
                isDark
                variant="underline"
              />
              <View style={styles.spacing} />
              <Input
                label="Password"
                value={password}
                onChangeText={setPassword}
                placeholder="Your password"
                secureTextEntry
                error={errors.password}
                isDark
                variant="underline"
              />
            </Animated.View>

          <Animated.View style={[styles.buttonContainer, { opacity: buttonFade }]}>
            <PrimaryButton
              text={loading ? 'Signing in...' : 'Sign In'}
              onPress={handleSignIn}
              theme="dark"
              disabled={loading}
            />
            <TouchableOpacity
              style={styles.switchAuth}
              onPress={() => navigation.navigate('SignUpPersonal')}
              activeOpacity={0.8}
            >
              <Text style={styles.switchAuthText}>Don't have an account? Get Started</Text>
            </TouchableOpacity>
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
  header: {
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
    paddingHorizontal: Spacing.lg,
  },
  heading: {
    fontSize: 32,
    lineHeight: 36,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    marginBottom: Spacing.lg,
  },
  inputsContainer: {
    gap: Spacing.md,
  },
  spacing: {
    height: Spacing.md,
  },
  buttonContainer: {
    paddingHorizontal: 0,
    paddingBottom: Spacing.lg,
    marginTop: Spacing.xl,
    gap: Spacing.md,
  },
  switchAuth: {
    alignItems: 'center',
  },
  switchAuthText: {
    color: Colors.white,
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
  },
});


