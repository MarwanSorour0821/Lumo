import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Circle } from 'react-native-svg';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { BloodTestAnalysisResponse } from '../lib/api';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';

type AnalysisResultsScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'AnalysisResults'>;
  route: RouteProp<RootStackParamList, 'AnalysisResults'>;
};

// Circular Progress Component
const CircularProgress = ({ percentage, size = 80, color = null }: { percentage: number; size?: number; color?: string | null }) => {
  const strokeWidth = 8;
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const strokeDashoffset = circumference - (percentage / 100) * circumference;
  
  const getColor = () => {
    if (color) return color;
    if (percentage >= 80) return '#10b981'; // green
    if (percentage >= 60) return '#f59e0b'; // yellow
    return '#ef4444'; // red
  };
  
  const progressColor = getColor();

  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size}>
        {/* Background circle */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke="rgba(255, 255, 255, 0.1)"
          strokeWidth={strokeWidth}
          fill="none"
        />
        {/* Progress circle */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={progressColor}
          strokeWidth={strokeWidth}
          fill="none"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </Svg>
      <View style={styles.progressTextContainer}>
        <Text style={[styles.progressText, { color: progressColor }]}>{percentage}%</Text>
      </View>
    </View>
  );
};

// Range Bar Component
const RangeBar = ({ value, min, max, unit, status }: { value: number; min: number; max: number; unit: string; status: string }) => {
  const percentage = ((value - min) / (max - min)) * 100;
  const clampedPercentage = Math.max(0, Math.min(100, percentage));
  
  const getColor = () => {
    if (status === 'normal') return '#10b981';
    if (status === 'low') return '#f59e0b';
    return '#ef4444';
  };

  return (
    <View style={styles.rangeBarContainer}>
      <View style={styles.rangeBarTrack}>
        {/* Low zone */}
        <View style={[styles.rangeZone, { backgroundColor: '#ef4444', width: '20%' }]} />
        {/* Normal zone */}
        <View style={[styles.rangeZone, { backgroundColor: '#10b981', width: '60%' }]} />
        {/* High zone */}
        <View style={[styles.rangeZone, { backgroundColor: '#ef4444', width: '20%' }]} />
        
        {/* Marker */}
        <View style={[styles.rangeMarker, { left: `${clampedPercentage}%`, backgroundColor: getColor() }]}>
          <View style={styles.markerDot} />
        </View>
      </View>
      
      <View style={styles.rangeLabels}>
        <Text style={styles.rangeLabel}>{min}</Text>
        <Text style={[styles.rangeValueText, { color: getColor() }]}>
          {value} {unit}
        </Text>
        <Text style={styles.rangeLabel}>{max}</Text>
      </View>
    </View>
  );
};

// Helper function to parse reference range
const parseReferenceRange = (referenceRange: string): { min: number; max: number } | null => {
  if (!referenceRange) return null;
  
  // Try to extract numbers from various formats like "11-16", "11 - 16", "11 to 16", etc.
  const match = referenceRange.match(/(\d+\.?\d*)\s*[-–—to]+\s*(\d+\.?\d*)/i);
  if (match) {
    return {
      min: parseFloat(match[1]),
      max: parseFloat(match[2])
    };
  }
  
  return null;
};

// Helper function to calculate overall health score
const calculateHealthScore = (testResults: any[]): number => {
  if (!testResults || testResults.length === 0) return 0;
  
  const normalCount = testResults.filter(r => r.status === 'normal').length;
  return Math.round((normalCount / testResults.length) * 100);
};

// Helper function to parse analysis text into insights
const parseAnalysisIntoInsights = (analysisText: string): Array<{category: string, icon: string, summary: string, details: string}> => {
  const insights = [];
  
  // Split by common section markers
  const sections = analysisText.split(/\n\s*\d+\.\s+/).filter(s => s.trim());
  
  if (sections.length > 0) {
    sections.forEach((section, index) => {
      const lines = section.trim().split('\n');
      const firstLine = lines[0] || '';
      const restOfText = lines.slice(1).join('\n').trim();
      
      // Extract category from first line or use default
      let category = 'Analysis';
      if (firstLine.includes('OVERVIEW') || firstLine.includes('Overview')) {
        category = 'Overview';
      } else if (firstLine.includes('FINDINGS') || firstLine.includes('Findings')) {
        category = 'Findings';
      } else if (firstLine.includes('RECOMMENDATIONS') || firstLine.includes('Recommendations')) {
        category = 'Recommendations';
      } else if (firstLine.includes('NOTES') || firstLine.includes('Notes')) {
        category = 'Notes';
      }
      
      const summary = firstLine.length > 100 ? firstLine.substring(0, 100) + '...' : firstLine;
      const details = restOfText || firstLine;
      
      const icons = ['medical-outline', 'water-outline', 'heart-outline', 'information-circle-outline'];
      
      insights.push({
        category,
        icon: icons[index % icons.length],
        summary,
        details: details || summary
      });
    });
  }
  
  // If no sections found, create a single insight from the whole text
  if (insights.length === 0) {
    const summary = analysisText.length > 100 ? analysisText.substring(0, 100) + '...' : analysisText;
    insights.push({
      category: 'Analysis',
      icon: 'medical-outline',
      summary,
      details: analysisText
    });
  }
  
  return insights;
};

export function AnalysisResultsScreen({ navigation, route }: AnalysisResultsScreenProps) {
  const { analysisData } = route.params;
  const [expandedSections, setExpandedSections] = useState({});

  const toggleSection = (section: string) => {
    setExpandedSections((prev: { [key: string]: boolean }) => ({
      ...prev,
      [section]: !prev[section]
    }));
  };

  // Calculate overall health score
  const testResults = analysisData.parsed_data.test_results || [];
  const overallScore = calculateHealthScore(testResults);
  
  // Calculate normal range percentage
  const normalCount = testResults.filter(r => r.status === 'normal').length;
  const normalRangePercentage = testResults.length > 0 ? Math.round((normalCount / testResults.length) * 100) : 0;
  const abnormalCount = testResults.length - normalCount;
  
  // Get patient info
  const patientInfo: any = analysisData.parsed_data.patient_info || {};
  
  // Format date helper
  const formatDate = (dateString: string | null | undefined) => {
    if (!dateString) return 'N/A';
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
    } catch {
      return dateString;
    }
  };

  // Get structured analysis - analysis is now JSON (structured_analysis)
  const structuredAnalysis = analysisData.analysis && typeof analysisData.analysis === 'object' 
    ? analysisData.analysis 
    : (analysisData as any).structured_analysis || null;
  
  // Get test overview from structured analysis
  const testOverview = structuredAnalysis?.test_overview || null;
  
  // Get sections from structured analysis, fallback to parsing if needed (for old data)
  const aiInsights = structuredAnalysis?.sections || 
    (typeof analysisData.analysis === 'string' ? parseAnalysisIntoInsights(analysisData.analysis) : []);

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
            })}
          </Text>
        </View>

        {/* Three Info Cards */}
        <View style={styles.infoCardsContainer}>
          {/* You Card */}
          <View style={styles.infoCard}>
            <Text style={styles.infoCardTitle}>{patientInfo.name || 'You'}</Text>
            {(patientInfo as any).birth_date && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Birth date</Text>
                <Text style={styles.infoValue}>{formatDate((patientInfo as any).birth_date)}</Text>
              </View>
            )}
            {patientInfo.age && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Age</Text>
                <Text style={styles.infoValue}>{patientInfo.age}</Text>
              </View>
            )}
            {(patientInfo as any).sex && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Gender</Text>
                <Text style={styles.infoValue}>{(patientInfo as any).sex}</Text>
              </View>
            )}
            {patientInfo.test_date && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Test Date</Text>
                <Text style={styles.infoValue}>{formatDate(patientInfo.test_date)}</Text>
              </View>
            )}
          </View>

          {/* Scan Card */}
          <View style={styles.infoCard}>
            <Text style={styles.infoCardTitle}>Scan</Text>
            {patientInfo.test_date && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Test Date</Text>
                <Text style={styles.infoValue}>{formatDate(patientInfo.test_date)}</Text>
              </View>
            )}
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Date Analyzed</Text>
              <Text style={styles.infoValue}>{formatDate(analysisData.created_at)}</Text>
            </View>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Test Type</Text>
              <Text style={styles.infoValue}>blood test</Text>
            </View>
            
            <View style={styles.biomarkerSummary}>
              <View style={styles.biomarkerStat}>
                <Text style={styles.biomarkerNumber}>{testResults.length}</Text>
                <Text style={styles.biomarkerLabel}>biomarkers</Text>
              </View>
              <View style={styles.biomarkerStat}>
                <Text style={[styles.biomarkerNumber, abnormalCount > 0 && styles.biomarkerNumberAbnormal]}>{abnormalCount}</Text>
                <Text style={styles.biomarkerLabel}>abnormal</Text>
              </View>
            </View>
          </View>

          {/* In Normal Range Card */}
          <View style={styles.infoCard}>
            <Text style={styles.normalRangeTitle}>In normal range</Text>
            <View style={styles.normalRangeCircleContainer}>
              <CircularProgress percentage={normalRangePercentage} size={120} color="#10b981" />
            </View>
            <Text style={styles.normalRangeSubtext}>of total biomarkers</Text>
          </View>
        </View>

        {/* Test Overview Section */}
        {testOverview && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Test Overview</Text>
            <Text style={styles.testOverviewText}>
              {testOverview}
            </Text>
          </View>
        )}

        {/* Category Sections with Biomarkers */}
        {aiInsights.length > 0 ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Analysis by Category</Text>
            
            {aiInsights.map((insight: any, index: number) => {
              // Get biomarkers for this category
              const categoryBiomarkers = insight.biomarkers || [];
              const categoryResults = testResults.filter((result: any) => 
                categoryBiomarkers.includes(result.marker)
              );
              
              return (
                <View key={index} style={styles.categorySection}>
                  {/* Category Header */}
                  <View style={styles.categoryHeader}>
                    <View style={styles.categoryHeaderLeft}>
                      <View style={styles.insightIconContainer}>
                        <Ionicons name={(insight.icon || 'medical-outline') as any} size={20} color={Colors.primary} />
                      </View>
                      <Text style={styles.categoryTitle}>{insight.category || 'Analysis'}</Text>
                    </View>
                  </View>
                  
                  {/* Summary */}
                  {insight.summary && (
                    <View style={styles.categorySummary}>
                      <Text style={styles.categorySummaryText}>{insight.summary}</Text>
                    </View>
                  )}
                  
                  {/* Details */}
                  {insight.details && (
                    <TouchableOpacity
                      onPress={() => toggleSection((insight.category || 'Section') + index)}
                      activeOpacity={0.7}
                    >
                      <View style={styles.categoryDetailsToggle}>
                        <Text style={styles.categoryDetailsToggleText}>
                          {(expandedSections as any)[(insight.category || 'Section') + index] 
                            ? 'Hide Details' 
                            : 'Show Details'}
                        </Text>
                        <Ionicons
                          name={(expandedSections as any)[(insight.category || 'Section') + index] ? 'chevron-up' : 'chevron-down'}
                          size={16}
                          color={Colors.primary}
                        />
                      </View>
                    </TouchableOpacity>
                  )}
                  
                  {/* Expanded Details */}
                  {(expandedSections as { [key: string]: boolean })[(insight.category || 'Section') + index] && insight.details && (
                    <View style={styles.categoryDetails}>
                      <Text style={styles.categoryDetailsText}>{insight.details}</Text>
                    </View>
                  )}
                  
                  {/* Biomarker Indicators for this Category */}
                  {categoryResults.length > 0 && (
                    <View style={styles.categoryBiomarkers}>
                      {categoryResults.map((result: any, resultIndex: number) => {
                        const parsedRange = parseReferenceRange(result.reference_range || '');
                        const numericValue = parseFloat(result.value);
                        
                        return (
                          <View key={resultIndex} style={styles.resultCard}>
                            <View style={styles.resultHeader}>
                              <Text style={styles.markerName}>{result.marker}</Text>
                              {result.status && (
                                <View style={[
                                  styles.statusBadge,
                                  result.status === 'normal' && styles.statusNormal,
                                  result.status === 'low' && styles.statusLow,
                                  result.status === 'high' && styles.statusHigh,
                                ]}>
                                  <Text style={styles.statusText}>{result.status.toUpperCase()}</Text>
                                </View>
                              )}
                            </View>
                            
                            {parsedRange && !isNaN(numericValue) ? (
                              <>
                                <RangeBar
                                  value={numericValue}
                                  min={parsedRange.min}
                                  max={parsedRange.max}
                                  unit={result.unit || ''}
                                  status={result.status || 'normal'}
                                />
                                <Text style={styles.referenceText}>
                                  Reference: {result.reference_range}
                                </Text>
                              </>
                            ) : (
                              <View style={styles.simpleValueContainer}>
                                <Text style={styles.simpleValue}>
                                  {result.value} {result.unit}
                                </Text>
                                {result.reference_range && (
                                  <Text style={styles.referenceText}>
                                    Reference: {result.reference_range}
                                  </Text>
                                )}
                              </View>
                            )}
                          </View>
                        );
                      })}
                    </View>
                  )}
                </View>
              );
            })}
          </View>
        ) : (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Test Results</Text>
            {testResults.length > 0 ? (
              testResults.map((result, index) => {
                const parsedRange = parseReferenceRange(result.reference_range || '');
                const numericValue = parseFloat(result.value);
                
                return (
                  <View key={index} style={styles.resultCard}>
                    <View style={styles.resultHeader}>
                      <Text style={styles.markerName}>{result.marker}</Text>
                      {result.status && (
                        <View style={[
                          styles.statusBadge,
                          result.status === 'normal' && styles.statusNormal,
                          result.status === 'low' && styles.statusLow,
                          result.status === 'high' && styles.statusHigh,
                        ]}>
                          <Text style={styles.statusText}>{result.status.toUpperCase()}</Text>
                        </View>
                      )}
                    </View>
                    
                    {parsedRange && !isNaN(numericValue) ? (
                      <>
                        <RangeBar
                          value={numericValue}
                          min={parsedRange.min}
                          max={parsedRange.max}
                          unit={result.unit || ''}
                          status={result.status || 'normal'}
                        />
                        <Text style={styles.referenceText}>
                          Reference: {result.reference_range}
                        </Text>
                      </>
                    ) : (
                      <View style={styles.simpleValueContainer}>
                        <Text style={styles.simpleValue}>
                          {result.value} {result.unit}
                        </Text>
                        {result.reference_range && (
                          <Text style={styles.referenceText}>
                            Reference: {result.reference_range}
                          </Text>
                        )}
                      </View>
                    )}
                  </View>
                );
              })
            ) : (
              <View style={styles.insightCard}>
                <Text style={styles.insightDetailsText}>
                  {structuredAnalysis?.test_overview || 'No detailed analysis available.'}
                </Text>
              </View>
            )}
          </View>
        )}

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
  infoCardsContainer: {
    flexDirection: 'column',
    gap: Spacing.md,
    marginBottom: Spacing.xl,
  },
  infoCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    borderWidth: 1,
    borderColor: Colors.dark.border,
  },
  infoCardTitle: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.md,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  infoLabel: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
  infoValue: {
    fontSize: FontSize.sm,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  },
  biomarkerSummary: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: Spacing.md,
    paddingTop: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.dark.border,
  },
  biomarkerStat: {
    alignItems: 'center',
  },
  biomarkerNumber: {
    fontSize: FontSize.xxl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: 2,
  },
  biomarkerNumberAbnormal: {
    color: '#ef4444',
  },
  biomarkerLabel: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
  },
  normalRangeTitle: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    marginBottom: Spacing.md,
  },
  normalRangeCircleContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: Spacing.md,
  },
  normalRangeSubtext: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginTop: Spacing.xs,
  },
  testOverviewText: {
    fontSize: FontSize.md,
    color: Colors.white,
    lineHeight: FontSize.md * 1.6,
  },
  scoreCard: {
    backgroundColor: 'rgba(176, 19, 40, 0.1)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    borderWidth: 1,
    borderColor: Colors.primary,
    marginBottom: Spacing.xl,
  },
  scoreHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  scoreTitle: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.xs,
  },
  scoreSubtitle: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
  },
  progressTextContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
  },
  progressText: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.bold,
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
  resultCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: Spacing.md,
  },
  resultHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  markerName: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.semibold,
    color: Colors.white,
  },
  statusBadge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 4,
    borderRadius: BorderRadius.sm,
  },
  statusNormal: {
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
  },
  statusLow: {
    backgroundColor: 'rgba(245, 158, 11, 0.2)',
  },
  statusHigh: {
    backgroundColor: 'rgba(239, 68, 68, 0.2)',
  },
  statusText: {
    fontSize: FontSize.xs,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  },
  rangeBarContainer: {
    marginBottom: Spacing.sm,
  },
  rangeBarTrack: {
    height: 8,
    borderRadius: 4,
    flexDirection: 'row',
    overflow: 'hidden',
    position: 'relative',
    marginBottom: Spacing.sm,
  },
  rangeZone: {
    height: '100%',
    opacity: 0.3,
  },
  rangeMarker: {
    position: 'absolute',
    top: -6,
    width: 20,
    height: 20,
    borderRadius: 10,
    transform: [{ translateX: -10 }],
    justifyContent: 'center',
    alignItems: 'center',
  },
  markerDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: 'white',
  },
  rangeLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  rangeLabel: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
  },
  rangeValueText: {
    fontSize: FontSize.sm,
    fontWeight: FontWeight.semibold,
  },
  referenceText: {
    fontSize: FontSize.xs,
    color: Colors.dark.textSecondary,
    marginTop: Spacing.xs,
  },
  simpleValueContainer: {
    marginTop: Spacing.sm,
  },
  simpleValue: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.primary,
    marginBottom: Spacing.xs,
  },
  insightCard: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    marginBottom: Spacing.md,
    overflow: 'hidden',
  },
  insightHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
  },
  insightIconContainer: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(176, 19, 40, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  insightHeaderText: {
    flex: 1,
  },
  insightCategory: {
    fontSize: FontSize.sm,
    fontWeight: FontWeight.semibold,
    color: Colors.primary,
    marginBottom: 2,
  },
  insightSummary: {
    fontSize: FontSize.sm,
    color: Colors.white,
  },
  insightDetails: {
    padding: Spacing.md,
    paddingTop: 0,
    borderTopWidth: 1,
    borderTopColor: Colors.dark.border,
  },
  insightDetailsText: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
    lineHeight: FontSize.sm * 1.5,
  },
  disclaimer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: 'rgba(245, 158, 11, 0.1)',
    borderRadius: BorderRadius.lg,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: 'rgba(245, 158, 11, 0.3)',
    gap: Spacing.sm,
  },
  disclaimerText: {
    flex: 1,
    fontSize: FontSize.sm,
    color: Colors.white,
    lineHeight: FontSize.sm * 1.5,
  },
  categorySection: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    padding: Spacing.lg,
    marginBottom: Spacing.lg,
    overflow: 'hidden',
  },
  categoryHeader: {
    marginBottom: Spacing.md,
  },
  categoryHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    flexShrink: 1,
  },
  categoryTitle: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginLeft: Spacing.md,
    flex: 1,
    flexShrink: 1,
  },
  categorySummary: {
    marginBottom: Spacing.md,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  categorySummaryText: {
    fontSize: FontSize.md,
    color: Colors.white,
    lineHeight: FontSize.md * 1.5,
  },
  categoryDetailsToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: Spacing.sm,
    marginBottom: Spacing.md,
  },
  categoryDetailsToggleText: {
    fontSize: FontSize.sm,
    color: Colors.primary,
    fontWeight: FontWeight.semibold,
  },
  categoryDetails: {
    marginBottom: Spacing.md,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  categoryDetailsText: {
    fontSize: FontSize.sm,
    color: Colors.white,
    lineHeight: FontSize.sm * 1.6,
  },
  categoryBiomarkers: {
    marginTop: Spacing.md,
  },
});
