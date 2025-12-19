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
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { RulerPicker } from 'react-native-ruler-picker';
import Svg, { Path } from 'react-native-svg';
import { TouchableOpacity } from 'react-native';
import BackButton from '../../components/BackButton';
import { ProgressBar } from '../components/ProgressBar';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList, BiologicalSex, SignUpData } from '../types';

type SignUpHeightScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'SignUpHeight'>;
  route: RouteProp<RootStackParamList, 'SignUpHeight'>;
};

export function SignUpHeightScreen({ navigation, route }: SignUpHeightScreenProps) {
  const { signUpData, sex, age } = route.params;
  
  const [height, setHeight] = useState<number>(170); // Default cm value
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;
  const previousHeightRef = useRef<number>(170);
  
  const screenWidth = Dimensions.get('window').width;

  // Convert cm to ft/in
  const cmToFeetInches = (cm: number) => {
    const totalInches = cm / 2.54;
    const feet = Math.floor(totalInches / 12);
    const inches = Math.round(totalInches % 12);
    return { feet, inches };
  };

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
    const heightNum = height;
    if (isNaN(heightNum) || heightNum < 100 || heightNum > 250) {
      Alert.alert('Please select a valid height between 100 and 250 cm');
      return;
    }
    navigation.navigate('SignUpWeight', { 
      signUpData, 
      sex, 
      age, 
      height: height.toString(), 
      heightFeet: '', 
      heightInches: '', 
      heightUnit: 'cm'
    });
  };

  // Ruler picker configuration for cm
  const rulerConfig = {
    min: 100,
    max: 250,
    step: 1,
    unit: 'cm',
  };

  const { feet, inches } = cmToFeetInches(height);

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.progressBarContainer}>
          <ProgressBar currentStep={3} totalSteps={7} />
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
                Your Height
              </Animated.Text>
              
              <Animated.Text 
                style={[
                  styles.subtitle,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                What is your height?
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
              <View style={styles.contentWrapper}>
                {/* Height Display */}
                <View style={styles.heightDisplayContainer}>
                  <Text style={styles.heightDisplay}>
                    {Math.round(height)} cm
                  </Text>
                  <Text style={styles.heightDisplayConverted}>
                    {feet} ft {inches} in
                  </Text>
                </View>

                {/* Ruler Picker */}
                <View style={styles.rulerContainer}>
                  {/* Left fade gradient */}
                  <LinearGradient
                    colors={[Colors.dark.background, 'transparent']}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 0 }}
                    style={styles.fadeGradientLeft}
                    pointerEvents="none"
                  />
                  <RulerPicker
                    min={rulerConfig.min}
                    max={rulerConfig.max}
                    step={rulerConfig.step}
                    initialValue={height}
                    onValueChange={(value: string) => {
                      const newHeight = Math.round(parseFloat(value));
                      if (newHeight !== previousHeightRef.current) {
                        previousHeightRef.current = newHeight;
                        setHeight(newHeight);
                        // Trigger haptic feedback when value changes
                        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      }
                    }}
                    onValueChangeEnd={(value: string) => {
                      const newHeight = Math.round(parseFloat(value));
                      setHeight(newHeight);
                      previousHeightRef.current = newHeight;
                    }}
                    unit={rulerConfig.unit}
                    height={180}
                    width={screenWidth}
                    indicatorColor={Colors.primary}
                    indicatorHeight={80}
                    gapBetweenSteps={10}
                    shortStepHeight={30}
                    longStepHeight={90}
                    stepWidth={1.5}
                    valueTextStyle={{
                      color: Colors.white,
                      fontSize: 16,
                    }}
                    unitTextStyle={{
                      color: Colors.white,
                      fontSize: 16,
                    }}
                    fractionDigits={0}
                  />
                  {/* Right fade gradient */}
                  <LinearGradient
                    colors={['transparent', Colors.dark.background]}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 0 }}
                    style={styles.fadeGradientRight}
                    pointerEvents="none"
                  />
                </View>
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
  headerContainer: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
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
    paddingVertical: Spacing.xl,
  },
  contentWrapper: {
    width: '100%',
  },
  heightDisplayContainer: {
    alignItems: 'center',
    marginBottom: Spacing.xl,
    marginTop: Spacing.lg,
  },
  heightDisplay: {
    fontSize: 48,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    textAlign: 'center',
  },
  heightDisplayConverted: {
    fontSize: 24,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginTop: Spacing.sm,
  },
  rulerContainer: {
    width: Dimensions.get('window').width,
    alignSelf: 'stretch',
    marginTop: Spacing.lg,
    marginBottom: Spacing.xl,
    marginLeft: -Spacing.lg,
    marginRight: -Spacing.lg,
    overflow: 'visible',
    position: 'relative',
  },
  fadeGradientLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: 60,
    zIndex: 1,
  },
  fadeGradientRight: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 60,
    zIndex: 1,
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
  nextButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
});


