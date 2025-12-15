import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
  Alert,
  Platform,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp, useFocusEffect } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, FontSize, FontWeight, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { BottomNavBar } from '../components/BottomNavBar';
import { getAnalyses, getAnalysis, AnalysisListItem } from '../lib/api';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

type MyLabScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'MyLab'>;
  route: RouteProp<RootStackParamList, 'MyLab'>;
};

export function MyLabScreen({ navigation, route }: MyLabScreenProps) {
  const [analyses, setAnalyses] = useState<AnalysisListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loadingAnalysisId, setLoadingAnalysisId] = useState<string | null>(null);

  const fetchAnalyses = async (showRefreshing = false) => {
    try {
      if (showRefreshing) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }
      setError(null);
      
      const data = await getAnalyses();
      setAnalyses(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load analyses');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  // Fetch analyses when screen comes into focus
  useFocusEffect(
    useCallback(() => {
      fetchAnalyses();
    }, [])
  );

  // Handle opening a specific analysis when navigated with openAnalysisId
  useEffect(() => {
    const openAnalysisId = route.params?.openAnalysisId;
    if (openAnalysisId) {
      handleOpenAnalysis(openAnalysisId);
    }
  }, [route.params?.openAnalysisId]);

  const handleOpenAnalysis = async (analysisId: string) => {
    setLoadingAnalysisId(analysisId);
    try {
      const analysisData = await getAnalysis(analysisId);
      navigation.navigate('AnalysisResults', {
        analysisData: {
          parsed_data: analysisData.parsed_data,
          analysis: analysisData.analysis,
          created_at: analysisData.created_at,
        },
        analysisId: analysisData.id,
      });
    } catch (err) {
      Alert.alert('Error', err instanceof Error ? err.message : 'Failed to load analysis');
    } finally {
      setLoadingAnalysisId(null);
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const getStatusColor = (summary: string) => {
    if (summary.includes('All markers normal')) {
      return '#22C55E'; // Green
    } else if (summary.includes('abnormal')) {
      return '#EF4444'; // Red
    }
    return Colors.dark.textSecondary;
  };

  const renderAnalysisCard = (item: AnalysisListItem) => (
    <TouchableOpacity
      key={item.id}
      style={styles.analysisCard}
      onPress={() => handleOpenAnalysis(item.id)}
      activeOpacity={0.7}
    >
      <View style={styles.cardContent}>
        <View style={styles.cardMainContent}>
          <View style={styles.cardInfo}>
            <Text style={styles.cardTitle} numberOfLines={1}>{item.title}</Text>
            <View style={styles.cardMeta}>
              <Text style={styles.cardDate}>{formatDate(item.created_at)}</Text>
              <View style={styles.metaDivider} />
              <Text style={styles.markersText}>{item.markers_count} markers</Text>
            </View>
            <Text style={[styles.summaryText, { color: getStatusColor(item.summary) }]} numberOfLines={1}>
              {item.summary}
            </Text>
          </View>
        </View>
        <View style={styles.chevronContainer}>
          {loadingAnalysisId === item.id ? (
            <ActivityIndicator size="small" color={Colors.primary} />
          ) : (
            <Ionicons name="chevron-forward" size={18} color={Colors.dark.textSecondary} />
          )}
        </View>
      </View>
    </TouchableOpacity>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Ionicons name="flask-outline" size={80} color={Colors.dark.textSecondary} />
      <Text style={styles.emptyTitle}>No Analyses Yet</Text>
      <Text style={styles.emptySubtitle}>
        Upload your first blood test to get started with AI-powered analysis
      </Text>
      <TouchableOpacity
        style={styles.startButton}
        onPress={() => navigation.navigate('Analyse')}
      >
        <Ionicons name="add" size={20} color={Colors.white} />
        <Text style={styles.startButtonText}>New Analysis</Text>
      </TouchableOpacity>
    </View>
  );

  const renderError = () => (
    <View style={styles.emptyState}>
      <Ionicons name="alert-circle-outline" size={80} color={Colors.primary} />
      <Text style={styles.emptyTitle}>Something Went Wrong</Text>
      <Text style={styles.emptySubtitle}>{error}</Text>
      <TouchableOpacity
        style={styles.startButton}
        onPress={() => fetchAnalyses()}
      >
        <Ionicons name="refresh" size={20} color={Colors.white} />
        <Text style={styles.startButtonText}>Try Again</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          bounces={true}
          alwaysBounceVertical={true}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={() => fetchAnalyses(true)}
              tintColor={Colors.primary}
              colors={[Colors.primary]}
              progressBackgroundColor={Colors.dark.surface}
            />
          }
        >
          <Text style={styles.title}>Your blood tests</Text>
          <Text style={styles.subtitle}>Your laboratory results and analysis</Text>

          {loading && !refreshing ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={Colors.primary} />
              <Text style={styles.loadingText}>Loading your analyses...</Text>
            </View>
          ) : error ? (
            renderError()
          ) : analyses.length === 0 ? (
            renderEmptyState()
          ) : (
            <View style={styles.analysesList}>
              {analyses.map(renderAnalysisCard)}
            </View>
          )}
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
    paddingTop: 40,
    paddingBottom: Spacing.xl,
    flexGrow: 1,
    minHeight: SCREEN_HEIGHT * 1.1, // Ensure content is always scrollable
  },
  title: {
    fontSize: FontSize.xxl,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
    marginBottom: Spacing.xl,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100,
  },
  loadingText: {
    marginTop: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
  },
  analysesList: {
    gap: Spacing.sm,
  },
  analysisCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    overflow: 'hidden',
  },
  cardContent: {
    padding: Spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
  },
  cardMainContent: {
    flex: 1,
    marginRight: Spacing.sm,
  },
  cardInfo: {
    flex: 1,
  },
  cardTitle: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    color: Colors.white,
    marginBottom: Spacing.xs,
  },
  cardMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
  },
  cardDate: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  metaDivider: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.dark.textSecondary,
  },
  markersText: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  summaryText: {
    fontSize: FontSize.sm,
    fontWeight: FontWeight.regular,
    fontFamily: 'ProductSans-Regular',
    marginTop: Spacing.xs,
  },
  chevronContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'flex-start',
    alignItems: 'center',
    paddingTop: Spacing.xl, // lift content higher on screen
    paddingHorizontal: Spacing.xl,
  },
  emptyTitle: {
    fontSize: FontSize.xl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginTop: Spacing.lg,
    marginBottom: Spacing.sm,
  },
  emptySubtitle: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.xl,
    lineHeight: FontSize.md * 1.5,
  },
  startButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.primary,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
  },
  startButtonText: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    color: Colors.white,
  },
});



