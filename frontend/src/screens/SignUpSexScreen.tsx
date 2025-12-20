import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TouchableOpacity,
  Animated,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import * as Haptics from 'expo-haptics';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Path } from 'react-native-svg';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, BiologicalSex, SignUpData } from '../types';

type SignUpSexScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpSex'>;
  route: RouteProp<RootStackParamList, 'SignUpSex'>;
};

export function SignUpSexScreen({ navigation, route }: SignUpSexScreenProps) {
  const { signUpData } = route.params;
  
  const [sex, setSex] = useState<BiologicalSex | null>(null);
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Animate heading and content on mount
    Animated.parallel([
      Animated.timing(headingFade, {
        toValue: 1,
        duration: 400,
        useNativeDriver: true,
      }),
      Animated.timing(contentFade, {
        toValue: 1,
        duration: 400,
        delay: 200,
        useNativeDriver: true,
      }),
      Animated.timing(buttonFade, {
        toValue: 1,
        duration: 400,
        delay: 400,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const handleContinue = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!sex) {
      Alert.alert('Please select your biological sex');
      return;
    }
    navigation.navigate('SignUpAge', { signUpData, sex });
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={1} totalSteps={7} />
        </View>
        
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
            <View style={styles.headingContainer}>
              <Animated.Text 
                style={[
                  styles.heading,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                What's your gender?
              </Animated.Text>
              
              <Animated.Text 
                style={[
                  styles.subtitle,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                This helps us personalize your blood analytics.
              </Animated.Text>
            </View>

            <Animated.View
              style={[
                styles.content,
                {
                  opacity: contentFade,
                }
              ]}
            >
              <View style={styles.sexOptions}>
                {(['male', 'female', 'other', 'prefer_not_to_say'] as BiologicalSex[]).map((sexOption) => (
                  <TouchableOpacity
                    key={sexOption}
                    activeOpacity={0.8}
                    onPress={() => {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      setSex(sexOption);
                    }}
                  >
                    <View
                      style={[
                        styles.sexOptionCard,
                        sex === sexOption && styles.sexOptionCardSelected,
                      ]}
                    >
                      {/* Icon */}
                      <View style={styles.sexOptionIcon}>
                        {sexOption === 'male' ? (
                          <Text style={[styles.sexIcon, sex === sexOption && styles.sexIconSelected]}>♂</Text>
                        ) : sexOption === 'female' ? (
                          <Text style={[styles.sexIcon, sex === sexOption && styles.sexIconSelected]}>♀</Text>
                        ) : sexOption === 'other' ? (
                          <Ionicons 
                            name="people" 
                            size={20} 
                            color={sex === sexOption ? Colors.primary : 'rgba(255, 255, 255, 0.7)'} 
                          />
                        ) : (
                          <Ionicons 
                            name="help-circle" 
                            size={20} 
                            color={sex === sexOption ? Colors.primary : 'rgba(255, 255, 255, 0.7)'} 
                          />
                        )}
                      </View>
                      
                      {/* Text */}
                      <Text
                        style={[
                          styles.sexOptionText,
                          sex === sexOption && styles.sexOptionTextSelected,
                        ]}
                      >
                        {sexOption === 'male' ? 'Male' : 
                         sexOption === 'female' ? 'Female' :
                         sexOption === 'other' ? 'Other' : 'Prefer not to say'}
                      </Text>
                      
                      <View style={{ flex: 1 }} />
                      
                      {/* Checkmark (only show when selected) */}
                      {sex === sexOption && (
                        <View style={styles.checkmarkContainer}>
                          <Svg width={14} height={14} viewBox="0 0 24 24">
                            <Path
                              fill="#B01328"
                              d="M17.517 7.957c.3.286.312.76.026 1.06l-6.667 7a.75.75 0 0 1-1.086 0l-3.333-3.5a.75.75 0 1 1 1.086-1.034l2.79 2.93l6.124-6.43a.75.75 0 0 1 1.06-.026"
                            />
                          </Svg>
                        </View>
                      )}
                    </View>
                  </TouchableOpacity>
                ))}
              </View>
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>

        {/* Bottom Navigation */}
        <View style={styles.bottomNavigation}>
          <View style={styles.bottomNavContent}>
            {/* Back Button */}
            <TouchableOpacity
              style={styles.backButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.goBack();
              }}
              activeOpacity={0.8}
            >
              <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M19 12H5M12 19l-7-7 7-7"
                  stroke="#000000"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
            </TouchableOpacity>

            {/* Next Button */}
            <TouchableOpacity
              style={[styles.nextButton, !sex && styles.nextButtonDisabled]}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                handleContinue();
              }}
              disabled={!sex}
              activeOpacity={0.9}
            >
              <Text style={styles.nextButtonText}>Next</Text>
              <Svg width={16} height={16} viewBox="0 0 24 24" fill="none">
                <Path
                  d="M5 12h14M12 5l7 7-7 7"
                  stroke="#FFFFFF"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </Svg>
            </TouchableOpacity>
          </View>
        </View>
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
  progressBarContainer: {
    alignItems: 'center',
    paddingTop: Spacing.md,
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
    paddingBottom: 100, // Extra padding for bottom button
  },
  headingContainer: {
    marginTop: 24,
    marginBottom: 32,
    alignItems: 'flex-start',
  },
  heading: {
    fontSize: 40,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    fontFamily: 'ProductSans-Regular',
    color: 'rgba(255, 255, 255, 0.7)',
  },
  content: {
    marginBottom: 48,
  },
  sexOptions: {
    gap: 12,
  },
  sexOptionCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 16,
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.2)',
  },
  sexOptionCardSelected: {
    borderWidth: 2,
    borderColor: Colors.primary,
  },
  sexOptionIcon: {
    width: 28,
    height: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  sexIcon: {
    fontSize: 20,
    color: 'rgba(255, 255, 255, 0.7)',
  },
  sexIconSelected: {
    color: Colors.primary,
  },
  sexOptionText: {
    fontSize: 17,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  sexOptionTextSelected: {
    fontFamily: 'ProductSans-Bold',
  },
  checkmarkContainer: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: Colors.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  bottomNavigation: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: Spacing.lg,
    paddingBottom: 40,
    backgroundColor: 'transparent',
  },
  bottomNavContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 12,
  },
  backButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.white,
    justifyContent: 'center',
    alignItems: 'center',
  },
  nextButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    height: 48,
    borderRadius: 22,
    backgroundColor: Colors.primary,
    elevation: 16,
    shadowColor: '#BB3E4F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.6,
    shadowRadius: 16,
    gap: 8,
  },
  nextButtonDisabled: {
    opacity: 0.5,
  },
  nextButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
});


