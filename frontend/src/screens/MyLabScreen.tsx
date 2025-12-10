import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Colors, Spacing, FontSize } from '../constants/theme';
import { RootStackParamList } from '../types';
import { BottomNavBar } from '../components/BottomNavBar';

type MyLabScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'MyLab'>;
};

export function MyLabScreen({ navigation }: MyLabScreenProps) {
  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.title}>My Lab</Text>
          <Text style={styles.subtitle}>Your laboratory results and analysis</Text>
        </ScrollView>
        <BottomNavBar currentRoute="MyLab" />
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
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingTop: 80,
    paddingBottom: Spacing.xl,
  },
  title: {
    fontSize: FontSize.xxxl,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    marginBottom: Spacing.md,
  },
  subtitle: {
    fontSize: FontSize.lg,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
});

