import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Input } from '../components/Input';
import { Button } from '../components/Button';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, FontWeight, Spacing } from '../constants/theme';
import { RootStackParamList } from '../types';

type SignUpPersonalScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpPersonal'>;
};

export function SignUpPersonalScreen({ navigation }: SignUpPersonalScreenProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});

  const validateForm = () => {
    const newErrors: Record<string, string> = {};
    
    if (!firstName.trim()) {
      newErrors.firstName = 'First name is required';
    }
    if (!lastName.trim()) {
      newErrors.lastName = 'Last name is required';
    }
    if (!email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      newErrors.email = 'Please enter a valid email';
    }
    if (!password) {
      newErrors.password = 'Password is required';
    } else if (password.length < 8) {
      newErrors.password = 'Password must be at least 8 characters';
    }
    if (password !== confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleContinue = () => {
    if (validateForm()) {
      navigation.navigate('SignUpBiometrics', {
        signUpData: {
          firstName,
          lastName,
          email,
          password,
        },
      });
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      {/* Background with blood tubes aesthetic */}
      <View style={styles.backgroundImage}>
        <View style={styles.tubesPattern}>
          {/* Decorative blood tube elements */}
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
        <ProgressBar currentStep={1} totalSteps={3} />
        
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
            <View style={styles.formContainer}>
              <View style={styles.row}>
                <View style={styles.halfInput}>
                  <Input
                    label="First Name"
                    value={firstName}
                    onChangeText={setFirstName}
                    placeholder="John"
                    autoCapitalize="words"
                    error={errors.firstName}
                    isDark={true}
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
                  />
                </View>
              </View>
              
              <Input
                label="Your email"
                value={email}
                onChangeText={setEmail}
                placeholder="i.e. johndoe@gmail.com"
                keyboardType="email-address"
                autoCapitalize="none"
                error={errors.email}
                isDark={true}
              />
              
              <Input
                label="Password"
                value={password}
                onChangeText={setPassword}
                placeholder="Enter your password"
                secureTextEntry
                error={errors.password}
                isDark={true}
              />
              
              <Input
                label="Confirm Password"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                placeholder="Confirm your password"
                secureTextEntry
                error={errors.confirmPassword}
                isDark={true}
              />
              
              <View style={styles.socialButtons}>
                <Button
                  title="Continue with iCloud"
                  onPress={() => {}}
                  variant="secondary"
                  icon={<Text style={styles.appleIcon}></Text>}
                />
                <View style={styles.socialSpacer} />
                <Button
                  title="Continue with google"
                  onPress={() => {}}
                  variant="secondary"
                  icon={<Text style={styles.googleIcon}>G</Text>}
                />
              </View>
            </View>
          </ScrollView>
          
          <View style={styles.buttonContainer}>
            <Button
              title="Continue"
              onPress={handleContinue}
              variant="primary"
            />
          </View>
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
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'flex-end',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xxl,
  },
  formContainer: {
    paddingBottom: Spacing.md,
  },
  row: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  halfInput: {
    flex: 1,
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
});

