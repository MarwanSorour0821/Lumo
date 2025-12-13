import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  Switch,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Notifications from 'expo-notifications';
import { Colors, Spacing, FontSize } from '../constants/theme';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';

type NotificationSettingsScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'NotificationSettings'>;
};

export function NotificationSettingsScreen({ navigation }: NotificationSettingsScreenProps) {
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkNotificationStatus();
  }, []);

  const checkNotificationStatus = async () => {
    try {
      const { status } = await Notifications.getPermissionsAsync();
      setNotificationsEnabled(status === 'granted');
    } catch (error) {
      console.error('Error checking notification status:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleNotifications = async (value: boolean) => {
    try {
      if (value) {
        // Request permission to enable notifications
        const { status: existingStatus } = await Notifications.getPermissionsAsync();
        let finalStatus = existingStatus;

        if (existingStatus !== 'granted') {
          const { status } = await Notifications.requestPermissionsAsync();
          finalStatus = status;
        }

        if (finalStatus !== 'granted') {
          Alert.alert(
            'Permission Required',
            'Please enable notifications in your device settings to receive notifications.',
            [
              {
                text: 'Cancel',
                style: 'cancel',
                onPress: () => setNotificationsEnabled(false),
              },
              {
                text: 'Open Settings',
                onPress: () => {
                  // On iOS, this will open the app settings
                  // On Android, it will open notification settings
                  Notifications.openSettingsAsync();
                },
              },
            ]
          );
          return;
        }

        setNotificationsEnabled(true);
      } else {
        // Disable notifications
        setNotificationsEnabled(false);
        // Note: We can't actually disable system permissions, but we can stop sending notifications
        Alert.alert(
          'Notifications Disabled',
          'You will no longer receive notifications. You can re-enable them anytime from this screen.'
        );
      }
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to update notification settings');
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header with Back Button */}
        <View style={styles.header}>
          <BackButton
            onPress={() => navigation.goBack()}
            theme="dark"
          />
        </View>

        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.title}>Notifications</Text>
          <Text style={styles.subtitle}>
            Manage your notification preferences
          </Text>

          <View style={styles.settingsCard}>
            <View style={styles.settingRow}>
              <View style={styles.settingLeft}>
                <Text style={styles.settingTitle}>Enable Notifications</Text>
                <Text style={styles.settingDescription}>
                  Receive push notifications for important updates
                </Text>
              </View>
              <Switch
                value={notificationsEnabled}
                onValueChange={handleToggleNotifications}
                trackColor={{ false: Colors.dark.border, true: Colors.primary }}
                thumbColor={Colors.white}
                disabled={loading}
              />
            </View>
          </View>
        </ScrollView>
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
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.xl,
  },
  title: {
    fontSize: 32,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    marginBottom: Spacing.xl,
  },
  settingsCard: {
    backgroundColor: Colors.dark.surface,
    borderRadius: 12,
    padding: Spacing.md,
  },
  settingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  settingLeft: {
    flex: 1,
    marginRight: Spacing.md,
  },
  settingTitle: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: 4,
  },
  settingDescription: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
});


