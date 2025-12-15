import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { Colors, FontSize, FontWeight, Spacing } from '../constants/theme';
import { BloodTestAnalysisResponse } from '../lib/api';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';

type AnalysisResultsScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'AnalysisResults'>;
  route: RouteProp<RootStackParamList, 'AnalysisResults'>;
};

export function AnalysisResultsScreen({ navigation, route }: AnalysisResultsScreenProps) {
  const { analysisData } = route.params;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.headerContainer}>
        <BackButton
          onPress={() => navigation.goBack()}
          theme="dark"
        />
      </View>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Blood Test Analysis</Text>
          <Text style={styles.date}>
            {new Date(analysisData.created_at).toLocaleDateString('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
          </Text>
        </View>

        {/* Patient Info */}
        {analysisData.parsed_data.patient_info && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Patient Information</Text>
            <View style={styles.card}>
              {analysisData.parsed_data.patient_info.name && (
                <Text style={styles.infoText}>Name: {analysisData.parsed_data.patient_info.name}</Text>
              )}
              {analysisData.parsed_data.patient_info.age && (
                <Text style={styles.infoText}>Age: {analysisData.parsed_data.patient_info.age}</Text>
              )}
              {analysisData.parsed_data.patient_info.test_date && (
                <Text style={styles.infoText}>Test Date: {analysisData.parsed_data.patient_info.test_date}</Text>
              )}
            </View>
          </View>
        )}

        {/* Test Results Summary */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Test Results</Text>
          {analysisData.parsed_data.test_results.map((result, index) => (
            <View key={index} style={[styles.card, styles.resultCard]}>
              <View style={styles.resultHeader}>
                <Text style={styles.markerName}>{result.marker}</Text>
                {result.status && (
                  <View style={[
                    styles.statusBadge,
                    result.status === 'high' && styles.statusHigh,
                    result.status === 'low' && styles.statusLow,
                    result.status === 'normal' && styles.statusNormal,
                  ]}>
                    <Text style={styles.statusText}>{result.status.toUpperCase()}</Text>
                  </View>
                )}
              </View>
              <Text style={styles.resultValue}>
                {result.value} {result.unit}
              </Text>
              <Text style={styles.resultRange}>
                Reference Range: {result.reference_range}
              </Text>
            </View>
          ))}
        </View>

        {/* AI Analysis */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>AI Analysis</Text>
          <View style={[styles.card, styles.analysisCard]}>
            <Text style={styles.analysisText}>{analysisData.analysis}</Text>
          </View>
        </View>

        {/* Disclaimer */}
        <View style={styles.disclaimer}>
          <Text style={styles.disclaimerText}>
            ⚠️ This analysis is AI-generated and should not replace professional medical advice. 
            Please consult with your healthcare provider for proper interpretation of your results.
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  headerContainer: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: Spacing.lg,
    paddingBottom: Spacing.xxl,
  },
  header: {
    marginBottom: Spacing.xl,
  },
  title: {
    fontSize: FontSize.xxl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.xs,
  },
  date: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
  section: {
    marginBottom: Spacing.xl,
  },
  sectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.md,
  },
  card: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: 12,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: Spacing.sm,
  },
  infoText: {
    fontSize: FontSize.md,
    color: Colors.white,
    marginBottom: Spacing.xs,
  },
  resultCard: {
    marginBottom: Spacing.md,
  },
  resultHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  markerName: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    color: Colors.white,
  },
  statusBadge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 4,
    borderRadius: 6,
  },
  statusNormal: {
    backgroundColor: 'rgba(34, 197, 94, 0.2)',
  },
  statusHigh: {
    backgroundColor: 'rgba(239, 68, 68, 0.2)',
  },
  statusLow: {
    backgroundColor: 'rgba(251, 191, 36, 0.2)',
  },
  statusText: {
    fontSize: FontSize.xs,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  },
  resultValue: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.primary,
    marginBottom: Spacing.xs,
  },
  resultRange: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
  analysisCard: {
    backgroundColor: 'rgba(176, 19, 40, 0.1)',
    borderColor: Colors.primary,
  },
  analysisText: {
    fontSize: FontSize.md,
    color: Colors.white,
    lineHeight: FontSize.md * 1.6,
  },
  disclaimer: {
    backgroundColor: 'rgba(251, 191, 36, 0.1)',
    borderRadius: 12,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: 'rgba(251, 191, 36, 0.3)',
  },
  disclaimerText: {
    fontSize: FontSize.sm,
    color: Colors.white,
    lineHeight: FontSize.sm * 1.5,
  },
});
