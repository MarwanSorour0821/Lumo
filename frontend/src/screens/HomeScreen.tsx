import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TextInput,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { getCurrentSession, getUserCreationDate } from '../lib/supabase';
import { BottomNavBar } from '../components/BottomNavBar';

type HomeScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Home'>;
};

// Chevron Left Icon
const ChevronLeftIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M15 18l-6-6 6-6"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Chevron Right Icon
const ChevronRightIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M9 18l6-6-6-6"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Search Icon
const SearchIcon = ({ size = 20, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Circle cx="11" cy="11" r="8" stroke={color} strokeWidth={2} />
    <Path d="m21 21-4.35-4.35" stroke={color} strokeWidth={2} strokeLinecap="round" />
  </Svg>
);

// Medical Cross/Star of Life Icon
const MedicalIcon = ({ size = 80, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 100 100" fill="none">
    <Circle cx="50" cy="50" r="45" stroke={color} strokeWidth={3} />
    <Path
      d="M50 25v50M25 50h50"
      stroke={color}
      strokeWidth={4}
      strokeLinecap="round"
    />
  </Svg>
);

// Flask/Test Tube Icon
const FlaskIcon = ({ size = 20, color = '#000000' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M9 2v6M15 2v6M9 8h6M7 8h10v12a2 2 0 01-2 2H9a2 2 0 01-2-2V8z"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M12 12v8M10 16h4"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
    />
  </Svg>
);

// Chevron Down Icon
const ChevronDownIcon = ({ size = 16, color = '#000000' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M6 9l6 6 6-6"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Arrow Right Icon (circular)
const ArrowRightIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Circle cx="12" cy="12" r="10" stroke={color} strokeWidth={1.5} />
    <Path
      d="M9 12l3 3 3-3M12 9v6"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

export function HomeScreen({ navigation }: HomeScreenProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [myTestsExpanded, setMyTestsExpanded] = useState(true);
  
  // Initialize selectedDate to today (without time)
  const getToday = () => {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    return date;
  };
  
  const [selectedDate, setSelectedDate] = useState(getToday());
  const [accountCreationDate, setAccountCreationDate] = useState<Date | null>(null);
  const [loading, setLoading] = useState(true);

  // Get current date (today)
  const today = getToday();

  // Load account creation date on mount
  useEffect(() => {
    const loadAccountCreationDate = async () => {
      try {
        const { data: sessionData } = await getCurrentSession();
        if (sessionData.user?.id) {
          const { data: creationDate } = await getUserCreationDate(sessionData.user.id);
          if (creationDate) {
            const date = new Date(creationDate);
            date.setHours(0, 0, 0, 0);
            setAccountCreationDate(date);
            // Set initial selected date to today (without time)
            const todayDate = new Date();
            todayDate.setHours(0, 0, 0, 0);
            setSelectedDate(todayDate);
          }
        }
      } catch (error) {
        console.error('Error loading account creation date:', error);
        // Default to today if error
        const todayDate = new Date();
        todayDate.setHours(0, 0, 0, 0);
        setAccountCreationDate(todayDate);
        setSelectedDate(todayDate);
      } finally {
        setLoading(false);
      }
    };

    loadAccountCreationDate();
  }, []);

  // Format date for display
  const formatDate = (date: Date) => {
    const dayName = date.toLocaleDateString('en-US', { weekday: 'long' });
    const dateString = date.toLocaleDateString('en-US', { 
      month: 'long', 
      day: 'numeric', 
      year: 'numeric' 
    });
    return { dayName, dateString };
  };

  // Check if we can go to previous day
  const canGoPrevious = () => {
    if (!accountCreationDate) return false;
    const prevDate = new Date(selectedDate);
    prevDate.setDate(prevDate.getDate() - 1);
    prevDate.setHours(0, 0, 0, 0);
    return prevDate >= accountCreationDate;
  };

  // Check if we can go to next day
  const canGoNext = () => {
    const nextDate = new Date(selectedDate);
    nextDate.setDate(nextDate.getDate() + 1);
    nextDate.setHours(0, 0, 0, 0);
    return nextDate <= today;
  };

  // Navigate to previous day
  const goToPreviousDay = () => {
    if (canGoPrevious()) {
      const prevDate = new Date(selectedDate);
      prevDate.setDate(prevDate.getDate() - 1);
      prevDate.setHours(0, 0, 0, 0);
      setSelectedDate(prevDate);
    }
  };

  // Navigate to next day
  const goToNextDay = () => {
    if (canGoNext()) {
      const nextDate = new Date(selectedDate);
      nextDate.setDate(nextDate.getDate() + 1);
      nextDate.setHours(0, 0, 0, 0);
      setSelectedDate(nextDate);
    }
  };

  const { dayName, dateString } = formatDate(selectedDate);
  const canGoPrev = canGoPrevious();
  const canGoNxt = canGoNext();

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Header with Date */}
          <View style={styles.header}>
            <TouchableOpacity 
              style={[styles.chevronButton, !canGoPrev && styles.chevronButtonDisabled]}
              onPress={goToPreviousDay}
              disabled={!canGoPrev}
              activeOpacity={0.6}
            >
              <ChevronLeftIcon 
                size={24} 
                color={Colors.white} 
              />
            </TouchableOpacity>
            <View style={styles.dateContainer}>
              <Text style={styles.dayName}>{dayName}</Text>
              <Text style={styles.dateText}>{dateString}</Text>
            </View>
            <TouchableOpacity 
              style={[styles.chevronButton, !canGoNxt && styles.chevronButtonDisabled]}
              onPress={goToNextDay}
              disabled={!canGoNxt}
              activeOpacity={0.6}
            >
              <ChevronRightIcon 
                size={24} 
                color={Colors.white} 
              />
            </TouchableOpacity>
          </View>

          {/* Welcome Message */}
          <Text style={styles.welcomeText}>
            Quick and easy medical advice at your fingertips
          </Text>

          {/* Search Bar */}
          <TouchableOpacity
            style={styles.searchContainer}
            onPress={() => navigation.navigate('Chat')}
            activeOpacity={0.8}
          >
            <TextInput
              style={styles.searchInput}
              placeholder="Ask your question"
              placeholderTextColor={Colors.dark.textSecondary}
              value={searchQuery}
              onChangeText={setSearchQuery}
              editable={false}
              pointerEvents="none"
            />
            <View style={styles.searchIconContainer}>
              <SearchIcon size={20} color={Colors.white} />
            </View>
          </TouchableOpacity>

          {/* Promotional Card */}
          <View style={styles.promoCard}>
            <View style={styles.promoContent}>
              <Text style={styles.promoText}>
                Make sense of your last test's analysis
              </Text>
              <View style={styles.promoButtons}>
                <TouchableOpacity style={styles.promoButton}>
                  <Text style={styles.promoButtonText}>Guide</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.promoButton}>
                  <Text style={styles.promoButtonText}>Tips</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.promoButton}>
                  <Text style={styles.promoButtonText}>Support</Text>
                </TouchableOpacity>
              </View>
            </View>
            <View style={styles.promoIconContainer}>
              <MedicalIcon size={100} color={Colors.white} />
            </View>
          </View>

          {/* My Tests Section */}
          <TouchableOpacity
            style={styles.myTestsHeader}
            onPress={() => setMyTestsExpanded(!myTestsExpanded)}
            activeOpacity={0.8}
          >
            <View style={styles.myTestsHeaderLeft}>
              <FlaskIcon size={20} color={Colors.black} />
              <Text style={styles.myTestsHeaderText}>MY TESTS (2)</Text>
            </View>
            <ChevronDownIcon size={16} color={Colors.black} />
          </TouchableOpacity>

          {/* Test List Items */}
          {myTestsExpanded && (
            <View style={styles.testList}>
              <TouchableOpacity style={styles.testItem} activeOpacity={0.8}>
                <View style={styles.testItemContent}>
                  <Text style={styles.testItemName}>Example test</Text>
                  <Text style={styles.testItemDate}>December 9, 2025 18:07</Text>
                </View>
                <ArrowRightIcon size={24} color={Colors.white} />
              </TouchableOpacity>
            </View>
          )}
        </ScrollView>
        <BottomNavBar currentRoute="Home" />
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: Spacing.xl,
  },
  chevronButton: {
    padding: Spacing.xs,
  },
  chevronButtonDisabled: {
    opacity: 0.4,
  },
  dateContainer: {
    alignItems: 'center',
  },
  dayName: {
    fontSize: 32,
    fontFamily: 'Georgia', // Serif font for day name
    color: Colors.white,
    marginBottom: 4,
  },
  dateText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  welcomeText: {
    fontSize: 28,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: Spacing.lg,
    lineHeight: 34,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.dark.surface,
    borderRadius: BorderRadius.xl,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    marginBottom: Spacing.lg,
  },
  searchInput: {
    flex: 1,
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    padding: 0,
  },
  searchIconContainer: {
    marginLeft: Spacing.sm,
  },
  promoCard: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.xl,
    padding: Spacing.lg,
    marginBottom: Spacing.xl,
    flexDirection: 'row',
    alignItems: 'center',
    overflow: 'hidden',
  },
  promoContent: {
    flex: 1,
  },
  promoText: {
    fontSize: 24,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    marginBottom: Spacing.md,
    lineHeight: 30,
  },
  promoButtons: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  promoButton: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.full,
    borderWidth: 1.5,
    borderColor: Colors.white,
    backgroundColor: Colors.primary,
  },
  promoButtonText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  promoIconContainer: {
    marginLeft: Spacing.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  myTestsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.white,
    borderRadius: BorderRadius.full,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    marginBottom: Spacing.md,
  },
  myTestsHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  myTestsHeaderText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Bold',
    color: Colors.black,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  testList: {
    gap: Spacing.md,
  },
  testItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.dark.surface,
    borderRadius: BorderRadius.lg,
    padding: Spacing.md,
  },
  testItemContent: {
    flex: 1,
  },
  testItemName: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    marginBottom: 4,
  },
  testItemDate: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
});

