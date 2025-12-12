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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp, useFocusEffect } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, FontSize, FontWeight, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { BottomNavBar } from '../components/BottomNavBar';
import { getAnalyses, getAnalysis, AnalysisListItem } from '../lib/api';

type MyLabScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'MyLab'>;
  route: RouteProp<RootStackParamList, 'MyLab'>;
};

export function MyLabScreen({ navigation, route }: MyLabScreenProps) {
  const [analyses, setAnalyses] = useState<AnalysisListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
        <View style={styles.cardHeader}>
          <View style={styles.iconContainer}>
            <Ionicons name="flask" size={24} color={Colors.primary} />
          </View>
          <View style={styles.cardInfo}>
            <Text style={styles.cardTitle}>{item.title}</Text>
            <Text style={styles.cardDate}>{formatDate(item.created_at)}</Text>
          </View>
          <Ionicons name="chevron-forward" size={20} color={Colors.dark.textSecondary} />
        </View>
        <View style={styles.cardFooter}>
          <View style={styles.markersBadge}>
            <Text style={styles.markersText}>{item.markers_count} markers</Text>
          </View>
          <Text style={[styles.summaryText, { color: getStatusColor(item.summary) }]}>
            {item.summary}
          </Text>
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
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={() => fetchAnalyses(true)}
              tintColor={Colors.primary}
            />
          }
        >
          <Text style={styles.title}>My Lab</Text>
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
    paddingTop: 80,
    paddingBottom: Spacing.xl,
    flexGrow: 1,
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
    gap: Spacing.md,
  },
  analysisCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    overflow: 'hidden',
  },
  cardContent: {
    padding: Spacing.md,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.md,
    backgroundColor: 'rgba(176, 19, 40, 0.15)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  cardInfo: {
    flex: 1,
  },
  cardTitle: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    color: Colors.white,
    marginBottom: 4,
  },
  cardDate: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
  cardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: Spacing.md,
    paddingTop: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.dark.border,
  },
  markersBadge: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    paddingHorizontal: Spacing.sm,
    paddingVertical: 4,
    borderRadius: BorderRadius.sm,
  },
  markersText: {
    fontSize: FontSize.xs,
    color: Colors.white,
    fontWeight: FontWeight.medium,
  },
  summaryText: {
    fontSize: FontSize.sm,
    fontWeight: FontWeight.medium,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 60,
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

