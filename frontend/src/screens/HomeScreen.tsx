import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Animated,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { getCurrentSession, getUserCreationDate } from '../lib/supabase';
import { BottomNavBar } from '../components/BottomNavBar';
import { getAnalyses, AnalysisListItem } from '../lib/api';
import { useFocusEffect } from '@react-navigation/native';
import { usePaywall } from '../contexts/PaywallContext';

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

// Document/Test Icon
const DocumentIcon = ({ size = 20, color = '#000000' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 512 512" fill="none">
    <Path
      fill={color}
      fillRule="evenodd"
      d="m384 85.333l85.334 85.333v256H42.667V85.333zM373.334 128h-288v256h341.333V181.333zm-224 42.666L149.333 320H384v21.334H128V170.666zm64 64v64h-42.667v-64zm64-42.666v106.666h-42.667V192zm64 64v42.666h-42.667V256z"
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
  <Svg width={size} height={size} viewBox="0 0 256 256" fill="none">
    <Path
      fill={color}
      d="M128 26a102 102 0 1 0 102 102A102.12 102.12 0 0 0 128 26Zm0 192a90 90 0 1 1 90-90a90.1 90.1 0 0 1-90 90Zm44.24-94.24a6 6 0 0 1 0 8.48l-32 32a6 6 0 0 1-8.48-8.48L153.51 134H88a6 6 0 0 1 0-12h65.51l-21.75-21.76a6 6 0 0 1 8.48-8.48Z"
    />
  </Svg>
);

export function HomeScreen({ navigation }: HomeScreenProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [myTestsExpanded, setMyTestsExpanded] = useState(false);
  const [analyses, setAnalyses] = useState<AnalysisListItem[]>([]);
  const [loadingTests, setLoadingTests] = useState(false);
  const [loadingAnalysisId, setLoadingAnalysisId] = useState<string | null>(null);
  // Animation values for smooth expand/collapse
  const expandAnim = useRef(new Animated.Value(0)).current;
  const chevronRotate = useRef(new Animated.Value(0)).current;
  
  // Paywall context
  const { hasActiveSubscription, canShowPaywall, trackUsageEvent } = usePaywall();
  
  // Track session start time to enforce 3-minute minimum
  const MIN_SESSION_TIME_MS = 3 * 60 * 1000; // 3 minutes
  const sessionStartTime = useRef(Date.now());
  
  // Check subscription and redirect to paywall if needed (only after first analysis)
  useFocusEffect(
    useCallback(() => {
      const checkPaywall = async () => {
        // Don't show paywall if user has active subscription
        if (hasActiveSubscription) {
          return;
        }

        // Track usage event
        await trackUsageEvent();

        // Check if we can show paywall (respects cooldown)
        const canShow = await canShowPaywall();
        
        if (canShow) {
          // Enforce 3-minute minimum session time
          const sessionTime = Date.now() - sessionStartTime.current;
          if (sessionTime < MIN_SESSION_TIME_MS) {
            return;
          }

          // Small delay to let the screen render first
          const timer = setTimeout(() => {
            navigation.navigate('PaywallMain');
          }, 500);
          return () => clearTimeout(timer);
        }
      };

      checkPaywall();
    }, [hasActiveSubscription, canShowPaywall, trackUsageEvent, navigation])
  );
  
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
          } else {
            // If we couldn't get creation date, allow navigation by leaving it null
            setAccountCreationDate(null);
          }
          // Set initial selected date to today (without time)
          const todayDate = new Date();
          todayDate.setHours(0, 0, 0, 0);
          setSelectedDate(todayDate);
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

  // Initialize animation state (already set to collapsed by default in refs)

  // Fetch analyses for current month
  const fetchAnalyses = async () => {
    try {
      setLoadingTests(true);
      const data = await getAnalyses();
      setAnalyses(data);
    } catch (error) {
      console.error('Error fetching analyses:', error);
      setAnalyses([]);
    } finally {
      setLoadingTests(false);
    }
  };

  // Fetch analyses when screen comes into focus
  useFocusEffect(
    useCallback(() => {
      fetchAnalyses();
    }, [])
  );

  // Filter analyses for the selected date's month
  const getSelectedMonthTests = () => {
    const selectedMonth = selectedDate.getMonth();
    const selectedYear = selectedDate.getFullYear();

    return analyses.filter((analysis) => {
      const analysisDate = new Date(analysis.created_at);
      return (
        analysisDate.getMonth() === selectedMonth &&
        analysisDate.getFullYear() === selectedYear
      );
    });
  };

  const selectedMonthTests = getSelectedMonthTests();

  // Format date for test item display
  const formatTestDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Handle test item press
  const handleTestPress = async (analysisId: string) => {
    setLoadingAnalysisId(analysisId);
    try {
      const { getAnalysis } = await import('../lib/api');
      const analysisData = await getAnalysis(analysisId);
      navigation.navigate('AnalysisResults', {
        analysisData: {
          parsed_data: analysisData.parsed_data,
          analysis: analysisData.analysis,
          created_at: analysisData.created_at,
        },
        analysisId: analysisData.id,
      });
    } catch (error) {
      console.error('Error loading analysis:', error);
    } finally {
      setLoadingAnalysisId(null);
    }
  };

  // Handle expand/collapse with animation
  const toggleTestsExpanded = () => {
    const toValue = myTestsExpanded ? 0 : 1;
    
    Animated.parallel([
      Animated.timing(expandAnim, {
        toValue,
        duration: 300,
        useNativeDriver: false, // Height animation requires layout
      }),
      Animated.timing(chevronRotate, {
        toValue,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();
    
    setMyTestsExpanded(!myTestsExpanded);
  };

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

  // Allow navigating to previous days without limit
  const canGoPrevious = () => true;

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
            {/* <View style={styles.promoIconContainer}>
              <MedicalIcon size={100} color={Colors.white} />
            </View> */}
          </View>

          {/* My Tests Section */}
          <TouchableOpacity
            style={styles.myTestsHeader}
            onPress={toggleTestsExpanded}
            activeOpacity={0.8}
          >
            <View style={styles.myTestsHeaderLeft}>
              <DocumentIcon size={20} color={Colors.black} />
              <View style={styles.myTestsHeaderTextContainer}>
                <Text style={styles.myTestsHeaderText}>MY TESTS</Text>
                <Text style={styles.testCountText}>{'\u0028'}{selectedMonthTests.length}{'\u0029'}</Text>
              </View>
            </View>
            <Animated.View
              style={{
                transform: [
                  {
                    rotate: chevronRotate.interpolate({
                      inputRange: [0, 1],
                      outputRange: ['0deg', '180deg'],
                    }),
                  },
                ],
              }}
            >
              <ChevronDownIcon size={16} color={Colors.black} />
            </Animated.View>
          </TouchableOpacity>

          {/* Test List Items */}
          <Animated.View
            style={{
              maxHeight: expandAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [0, 1000], // Adjust based on max expected height
              }),
              opacity: expandAnim,
              overflow: 'hidden',
            }}
          >
            <View style={styles.testList}>
              {loadingTests ? (
                <View style={styles.loadingContainer}>
                  <Text style={styles.loadingText}>Loading tests...</Text>
                </View>
              ) : selectedMonthTests.length === 0 ? (
                <View style={styles.emptyContainer}>
                  <Text style={styles.emptyText}>No tests this month</Text>
                </View>
              ) : (
                selectedMonthTests.map((test) => (
                  <TouchableOpacity
                    key={test.id}
                    style={styles.testItem}
                    activeOpacity={0.8}
                    onPress={() => handleTestPress(test.id)}
                  >
                    <View style={styles.testItemContent}>
                      <Text style={styles.testItemName}>{test.title}</Text>
                      <Text style={styles.testItemDate}>{formatTestDate(test.created_at)}</Text>
                    </View>
                    {loadingAnalysisId === test.id ? (
                      <ActivityIndicator size="small" color={Colors.white} />
                    ) : (
                      <ArrowRightIcon size={24} color={Colors.white} />
                    )}
                  </TouchableOpacity>
                ))
              )}
            </View>
          </Animated.View>
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
    paddingTop: 40,
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
    fontFamily: 'ProductSans-Regular',
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
  myTestsHeaderTextContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
  },
  myTestsHeaderText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Bold',
    color: Colors.black,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  testCountText: {
    fontSize: FontSize.sm,
    fontFamily: 'System', // Use system font to avoid font-specific rendering issues
    color: Colors.black,
    textTransform: 'none',
    letterSpacing: 0,
    fontWeight: '400',
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
  loadingContainer: {
    padding: Spacing.md,
    alignItems: 'center',
  },
  loadingText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
  emptyContainer: {
    padding: Spacing.md,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
});



