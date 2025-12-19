import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  Animated,
  Alert,
  KeyboardAvoidingView,
  Platform,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Picker } from '@react-native-picker/picker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import * as Haptics from 'expo-haptics';
import Svg, { Path } from 'react-native-svg';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, Spacing } from '../constants/theme';
import { RootStackParamList, BiologicalSex, SignUpData } from '../types';

type SignUpAgeScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpAge'>;
  route: RouteProp<RootStackParamList, 'SignUpAge'>;
};

export function SignUpAgeScreen({ navigation, route }: SignUpAgeScreenProps) {
  const { signUpData, sex } = route.params;
  
  const [age, setAge] = useState<number>(24);
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

  // Generate age options from 18 to 100
  const ageOptions = Array.from({ length: 83 }, (_, i) => i + 18);

  useEffect(() => {
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
    if (!age || age < 18 || age > 100) {
      Alert.alert('Please select a valid age between 18 and 100');
      return;
    }
    navigation.navigate('SignUpHeight', { signUpData, sex, age: age.toString() });
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={2} totalSteps={7} />
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
                Your Age
              </Animated.Text>
              
              <Animated.Text 
                style={[
                  styles.subtitle,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                How old are you?
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
              <View style={styles.pickerContainer}>
                <Picker
                  selectedValue={age}
                  onValueChange={(itemValue) => setAge(itemValue as number)}
                  style={styles.picker}
                  itemStyle={styles.pickerItem}
                >
                  {ageOptions.map((ageOption) => (
                    <Picker.Item
                      key={ageOption}
                      label={ageOption.toString()}
                      value={ageOption}
                    />
                  ))}
                </Picker>
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
              style={styles.nextButton}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                handleContinue();
              }}
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
  progressBarContainer: {
    alignItems: 'center',
    paddingTop: Spacing.md,
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
  nextButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
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
  },
  headingContainer: {
    marginTop: Spacing.xl,
    marginBottom: Spacing.xxl,
  },
  heading: {
    fontSize: 40,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    marginTop: Spacing.xs,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  pickerContainer: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  picker: {
    width: 200,
    height: 200,
    color: Colors.white,
  },
  pickerItem: {
    color: Colors.white,
    fontSize: FontSize.xl,
    fontFamily: 'ProductSans-Regular',
  },
  buttonContainer: {
    paddingBottom: Spacing.lg,
  },
});


