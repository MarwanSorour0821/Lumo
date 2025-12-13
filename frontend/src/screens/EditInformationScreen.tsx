import React, { useEffect, useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  Alert,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import BackButton from '../../components/BackButton';
import PrimaryButton from '../../components/PrimaryButton';
import { Input } from '../components/Input';
import { Colors, Spacing, FontSize } from '../constants/theme';
import { RootStackParamList } from '../types';
import {
  getCurrentSession,
  getUserProfile,
  updateUserProfile,
  updateUserPassword,
} from '../lib/supabase';

type EditInformationScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'EditInformation'>;
};

export function EditInformationScreen({ navigation }: EditInformationScreenProps) {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loadingProfile, setLoadingProfile] = useState(true);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);

  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(headingFade, { toValue: 1, duration: 400, useNativeDriver: true }),
      Animated.timing(contentFade, { toValue: 1, duration: 400, delay: 150, useNativeDriver: true }),
    ]).start();
  }, [headingFade, contentFade]);

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const { data: sessionData, error: sessionError } = await getCurrentSession();
        if (sessionError || !sessionData.user?.id) {
          Alert.alert('Error', sessionError?.message || 'No session found');
          return;
        }

        const userId = sessionData.user.id;
        const { data: profile, error: profileError } = await getUserProfile(userId);
        if (profileError) {
          Alert.alert('Error', profileError.message);
          return;
        }

        if (profile) {
          setFirstName(profile.first_name || '');
          setLastName(profile.last_name || '');
          setEmail(profile.email || sessionData.user.email || '');
        } else {
          setEmail(sessionData.user.email || '');
        }
      } catch (error: any) {
        Alert.alert('Error', error?.message || 'Failed to load profile');
      } finally {
        setLoadingProfile(false);
      }
    };

    loadProfile();
  }, []);

  const handleSaveProfile = async () => {
    if (!firstName.trim() || !lastName.trim() || !email.trim()) {
      Alert.alert('Validation', 'First name, last name, and email are required.');
      return;
    }

    setSavingProfile(true);
    try {
      const { data: sessionData, error: sessionError } = await getCurrentSession();
      if (sessionError || !sessionData.user?.id) {
        Alert.alert('Error', sessionError?.message || 'No session found');
        setSavingProfile(false);
        return;
      }

      const userId = sessionData.user.id;
      const { error } = await updateUserProfile(userId, {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
      });

      if (error) {
        Alert.alert('Error', error.message);
      } else {
        Alert.alert('Success', 'Profile updated successfully.');
      }
    } catch (error: any) {
      Alert.alert('Error', error?.message || 'Failed to update profile');
    } finally {
      setSavingProfile(false);
    }
  };

  const handleChangePassword = async () => {
    if (!newPassword.trim() || !confirmPassword.trim()) {
      Alert.alert('Validation', 'Please enter and confirm your new password.');
      return;
    }
    if (newPassword !== confirmPassword) {
      Alert.alert('Validation', 'Passwords do not match.');
      return;
    }
    if (newPassword.length < 8) {
      Alert.alert('Validation', 'Password must be at least 8 characters.');
      return;
    }

    setSavingPassword(true);
    try {
      const { error } = await updateUserPassword(newPassword);
      if (error) {
        Alert.alert('Error', error.message);
      } else {
        Alert.alert('Success', 'Password updated successfully.');
        setNewPassword('');
        setConfirmPassword('');
      }
    } catch (error: any) {
      Alert.alert('Error', error?.message || 'Failed to update password');
    } finally {
      setSavingPassword(false);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <View style={styles.header}>
          <BackButton onPress={() => navigation.goBack()} theme="dark" />
        </View>

        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}
        >
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            <Animated.Text style={[styles.heading, { opacity: headingFade }]}>
              Edit Information
            </Animated.Text>

            <Animated.View style={[styles.section, { opacity: contentFade }]}>
              <Text style={styles.sectionTitle}>Profile</Text>
              <Input
                label="First name"
                value={firstName}
                onChangeText={setFirstName}
                placeholder="First name"
                isDark
                variant="underline"
                editable={!loadingProfile && !savingProfile}
              />
              <View style={styles.inputSpacer} />
              <Input
                label="Last name"
                value={lastName}
                onChangeText={setLastName}
                placeholder="Last name"
                isDark
                variant="underline"
                editable={!loadingProfile && !savingProfile}
              />
              <View style={styles.inputSpacer} />
              <Input
                label="Email"
                value={email}
                onChangeText={setEmail}
                placeholder="you@example.com"
                keyboardType="email-address"
                autoCapitalize="none"
                isDark
                variant="underline"
                editable={!loadingProfile && !savingProfile}
              />
              <View style={styles.buttonSpacer} />
              <PrimaryButton
                text={savingProfile ? 'Saving...' : 'Save profile'}
                onPress={handleSaveProfile}
                theme="dark"
                disabled={savingProfile || loadingProfile}
              />
            </Animated.View>

            <Animated.View style={[styles.section, { opacity: contentFade }]}>
              <Text style={styles.sectionTitle}>Password</Text>
              <Input
                label="New password"
                value={newPassword}
                onChangeText={setNewPassword}
                placeholder="Enter new password"
                secureTextEntry
                isDark
                variant="underline"
                editable={!savingPassword}
              />
              <View style={styles.inputSpacer} />
              <Input
                label="Confirm new password"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                placeholder="Confirm new password"
                secureTextEntry
                isDark
                variant="underline"
                editable={!savingPassword}
              />
              <View style={styles.buttonSpacer} />
              <PrimaryButton
                text={savingPassword ? 'Updating...' : 'Change password'}
                onPress={handleChangePassword}
                theme="dark"
                disabled={savingPassword}
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
    flexGrow: 1,
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xl,
    paddingTop: Spacing.md,
    gap: Spacing.xl,
  },
  heading: {
    fontSize: 32,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    marginBottom: Spacing.md,
  },
  section: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 16,
    padding: Spacing.lg,
    gap: Spacing.sm,
  },
  sectionTitle: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  inputSpacer: {
    height: Spacing.sm,
  },
  buttonSpacer: {
    height: Spacing.md,
  },
});


