import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View, Animated, ScrollView, TouchableOpacity, Image, Dimensions } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import Svg, { Path } from 'react-native-svg';
import { PrimaryButton } from '../components';
import { colors, Theme } from '../constants/theme';
import { RootStackParamList } from '../src/types';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface OnboardingScreenProps {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Onboarding'>;
  theme?: Theme;
  onGetStarted?: () => void;
}

const createStyles = (theme: Theme) => StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 24,
    position: 'relative',
  },
  pageFill: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#B01328',
    zIndex: 2, // Above slider (1), below bottomSection (3)
    overflow: 'visible',
  },
  waveContainer: {
    position: 'absolute',
    top: -29,
    left: 0,
    width: SCREEN_WIDTH * 40, // Much longer pattern (40x) for seamless looping
  },
  scrollViewContainer: {
    position: 'relative',
    zIndex: 0,
  },
  scrollContent: {
    flexGrow: 1,
    paddingVertical: 40,
    paddingBottom: 300, // Space for absolutely positioned bottomSection
  },
  sliderContainer: {
    marginBottom: 32,
    marginTop: 60,
    position: 'relative',
    zIndex: 1,
  },
  sliderWrapper: {
    position: 'relative',
    width: SCREEN_WIDTH - 48,
    height: 300,
    borderRadius: 20,
    overflow: 'hidden',
  },
  imageSlider: {
    width: SCREEN_WIDTH - 48,
    height: 300,
  },
  imageContainer: {
    width: SCREEN_WIDTH - 48,
    height: 300,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sliderImage: {
    width: SCREEN_WIDTH - 48,
    height: 300,
  },
  sliderImageContain: {
    width: '90%',
    height: '90%',
    maxWidth: SCREEN_WIDTH - 48,
    maxHeight: 300,
  },
  sliderImageLarge: {
    width: '100%',
    height: '100%',
    maxWidth: SCREEN_WIDTH - 48,
    maxHeight: 300,
  },
  bottomGradient: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 150,
  },
  paginationContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 16,
    gap: 8,
  },
  paginationDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
  },
  paginationDotActive: {
    width: 24,
    backgroundColor: '#B01328',
  },
  bottomSection: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: 24,
    paddingBottom: 40,
    zIndex: 3, // Above fill (2)
    backgroundColor: 'transparent',
  },
  content: {
    marginBottom: 32,
    position: 'relative',
    zIndex: 4,
  },
  mainText: {
    fontSize: 40,
    textAlign: 'center',
    lineHeight: 40,
    marginBottom: 24,
    fontFamily: 'ProductSans-Regular',
    position: 'relative',
    zIndex: 5,
  },
  subText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
    fontFamily: 'ProductSans-Regular',
    position: 'relative',
    zIndex: 5,
  },
  signInLink: {
    marginTop: 16,
    alignItems: 'center',
  },
  signInText: {
    fontSize: 14,
    fontFamily: 'ProductSans-Regular',
  },
  signInTextBold: {
    fontFamily: 'ProductSans-Bold',
  },
  interactiveButtonContainer: {
    width: '100%',
    marginBottom: 16,
  },
  interactiveButton: {
    width: '100%',
    height: 56,
    borderRadius: 28,
    overflow: 'hidden',
    backgroundColor: '#B01328',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  buttonContent: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    position: 'relative',
    overflow: 'hidden',
    borderRadius: 28,
  },
  progressFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
    borderRadius: 28,
  },
  buttonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    zIndex: 1,
  },
});

export default function OnboardingScreen({ 
  navigation,
  theme = 'dark',
  onGetStarted 
}: OnboardingScreenProps) {
  const themeColors = colors[theme];
  const styles = createStyles(theme);
  const mainTextFade = useRef(new Animated.Value(0)).current;
  const mainTextSlide = useRef(new Animated.Value(30)).current;
  const subTextFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;
  
  // Interactive button state
  const [isHolding, setIsHolding] = useState(false);
  const [progress, setProgress] = useState(0);
  const progressAnim = useRef(new Animated.Value(0)).current;
  const buttonScale = useRef(new Animated.Value(1)).current;
  const currentProgressRef = useRef(0);
  
  // Wave animation
  const waveAnim = useRef(new Animated.Value(0)).current;
  
  // Image slider state
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const scrollViewRef = useRef<ScrollView>(null);
  const images = [
    require('../assets/images/Group 6.png'),
    require('../assets/images/iMockup - iPhone 14.png'),
  ];

  useEffect(() => {
    // Animate main text: fade in + slide up
    Animated.parallel([
      Animated.timing(mainTextFade, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.timing(mainTextSlide, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      }),
    ]).start();

    // Animate sub text: fade in only (with delay)
    Animated.timing(subTextFade, {
      toValue: 1,
      duration: 600,
      delay: 200,
      useNativeDriver: true,
    }).start();

    // Animate button: fade in (with delay)
    Animated.timing(buttonFade, {
      toValue: 1,
      duration: 600,
      delay: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  // Continuous wave animation - faster and infinite loop with much longer pattern
  useEffect(() => {
    waveAnim.setValue(0);
    const waveAnimationDistance = SCREEN_WIDTH * 20; // Move 20x screen width before looping (half of 40x pattern)
    Animated.loop(
      Animated.timing(waveAnim, {
        toValue: waveAnimationDistance, // Move 20x screen width before looping
        duration: 30000, // 30 seconds for one full cycle (much longer)
        useNativeDriver: true, // Using translateX transform
      }),
      { iterations: -1 } // Infinite loop
    ).start();
  }, []);

  // Handle button press start
  const handlePressIn = () => {
    setIsHolding(true);
    setProgress(0);
    progressAnim.setValue(0);
    currentProgressRef.current = 0;
    
    // Initial haptic feedback
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    
    // Animate button scale down slightly
    Animated.spring(buttonScale, {
      toValue: 0.98,
      useNativeDriver: true,
    }).start();
    
    // Track previous progress for haptic feedback
    let previousProgress = 0;
    
    // Add listener for progress updates
    const progressListener = progressAnim.addListener(({ value }) => {
      const currentProgress = Math.round(value * 100);
      currentProgressRef.current = currentProgress;
      setProgress(currentProgress);
      
      // Trigger haptic feedback every time percentage increases
      if (currentProgress > previousProgress) {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        previousProgress = currentProgress;
      }
    });
    
    // Start progress animation with easing for acceleration
    Animated.timing(progressAnim, {
      toValue: 1,
      duration: 800, // 0.8 seconds to fill (even faster)
      easing: (t) => t * t, // Quadratic easing - accelerates over time
      useNativeDriver: false,
    }).start(({ finished }) => {
      progressAnim.removeListener(progressListener);
      if (finished) {
        // Progress complete - navigate
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        if (onGetStarted) {
          onGetStarted();
        } else {
          navigation.navigate('SignUpPersonal');
        }
        handlePressOut();
      }
    });
  };

  // Handle button press release
  const handlePressOut = () => {
    setIsHolding(false);
    
    // Animate button scale back
    Animated.spring(buttonScale, {
      toValue: 1,
      useNativeDriver: true,
    }).start();
    
    // Reset progress if not complete - smooth unfill animation
    if (progress < 100) {
      progressAnim.stopAnimation();
      Animated.timing(progressAnim, {
        toValue: 0,
        duration: 400,
        easing: (t) => 1 - Math.pow(1 - t, 3), // Ease out cubic for smooth liquid-like unfill
        useNativeDriver: false,
      }).start();
      setProgress(0);
      currentProgressRef.current = 0;
    }
  };

  const handleScroll = (event: any) => {
    const scrollPosition = event.nativeEvent.contentOffset.x;
    const index = Math.round(scrollPosition / SCREEN_WIDTH);
    setCurrentImageIndex(index);
  };

  return (
    <View style={[styles.container, { backgroundColor: themeColors.background }]}>
      <StatusBar style="light" />
      
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        style={styles.scrollViewContainer}
      >
        {/* Image Slider */}
        <View style={styles.sliderContainer}>
          <View style={styles.sliderWrapper}>
            <ScrollView
              ref={scrollViewRef}
              horizontal
              pagingEnabled
              showsHorizontalScrollIndicator={false}
              onScroll={handleScroll}
              scrollEventThrottle={16}
              style={styles.imageSlider}
            >
              {images.map((image, index) => (
                <View key={index} style={styles.imageContainer}>
                  <Image
                    source={image}
                    style={index === 0 ? styles.sliderImageLarge : styles.sliderImageContain}
                    resizeMode="contain"
                  />
                </View>
              ))}
            </ScrollView>
            
            {/* Bottom gradient overlay */}
            <LinearGradient
              colors={[themeColors.background, 'transparent']}
              start={{ x: 0, y: 1 }}
              end={{ x: 0, y: 0 }}
              style={styles.bottomGradient}
              pointerEvents="none"
            />
          </View>
          
          {/* Pagination Dots */}
          <View style={styles.paginationContainer}>
            {images.map((_, index) => (
              <View
                key={index}
                style={[
                  styles.paginationDot,
                  index === currentImageIndex && styles.paginationDotActive,
                ]}
              />
            ))}
          </View>
        </View>
      </ScrollView>
      
      {/* Bottom Section - outside ScrollView so it can be above the fill */}
        <View style={styles.bottomSection}>
          <View style={styles.content}>
            <Animated.Text 
              style={[
                styles.mainText, 
                { 
                  color: themeColors.primaryText,
                  opacity: mainTextFade,
                  transform: [{ translateY: mainTextSlide }],
                }
              ]}
            >
              Top-class premium{'\n'}analysis on your{'\n'}blood tests at your{'\n'}finger tips.
            </Animated.Text>
            
            <Animated.Text 
              style={[
                styles.subText, 
                { 
                  color: themeColors.secondaryText,
                  opacity: subTextFade,
                }
              ]}
            >
              Create an account and join thousands of{'\n'}people who are already using our app.
            </Animated.Text>
          </View>

          <Animated.View
            style={{
              opacity: buttonFade,
            position: 'relative',
            zIndex: 4,
            }}
          >
          <View style={styles.interactiveButtonContainer}>
            <TouchableOpacity
              activeOpacity={1}
              onPressIn={handlePressIn}
              onPressOut={handlePressOut}
              style={styles.interactiveButton}
            >
              <Animated.View
                style={[
                  styles.buttonContent,
                  {
                    transform: [{ scale: buttonScale }],
                  },
                ]}
              >
                {/* Progress fill background */}
                <Animated.View
                  style={[
                    styles.progressFill,
                    {
                      width: progressAnim.interpolate({
                        inputRange: [0, 1],
                        outputRange: [0, SCREEN_WIDTH - 48],
                      }),
                    },
                  ]}
                />
                
                {/* Button text */}
                <Text style={[styles.buttonText, { color: themeColors.buttonText || '#FFFFFF' }]}>
                  {isHolding ? `Hold to continue... ${Math.round(progress)}%` : 'Hold to Get Started'}
                </Text>
              </Animated.View>
            </TouchableOpacity>
          </View>
          
            <TouchableOpacity
              style={styles.signInLink}
              onPress={() => navigation.navigate('Login')}
              activeOpacity={0.8}
            >
              <Text style={[styles.signInText, { color: themeColors.secondaryText }]}>
                Already have an account?{' '}
                <Text style={[styles.signInTextBold, { color: themeColors.primaryText }]}>Sign in</Text>
              </Text>
            </TouchableOpacity>
          </Animated.View>
        </View>
      
      {/* Red fill effect - fills from bottom to top with wavy top - only visible when holding */}
      <Animated.View
        style={[
          styles.pageFill,
          {
            height: progressAnim.interpolate({
              inputRange: [0, 1],
              outputRange: [0, SCREEN_HEIGHT],
            }),
            opacity: progressAnim.interpolate({
              inputRange: [0, 0.01, 1],
              outputRange: [0, 1, 1], // Fade in immediately when progress starts
            }),
          },
        ]}
        pointerEvents="none"
      >
        {/* Wavy top edge - animated horizontally with much longer seamless pattern (40x) */}
        <Animated.View
          style={[
            styles.waveContainer,
            {
              transform: [
                {
                  translateX: waveAnim.interpolate({
                    inputRange: [0, SCREEN_WIDTH * 20],
                    outputRange: [0, -(SCREEN_WIDTH * 20)],
                  }),
                },
              ],
            },
          ]}
        >
          <Svg
            width={SCREEN_WIDTH * 40}
            height={30}
            viewBox={`0 0 ${SCREEN_WIDTH * 40} 30`}
          >
            {/* Generate seamless repeating wave pattern (40x screen width) */}
            <Path
              d={(() => {
                // Base pattern that repeats every 2x screen width
                const basePattern = `M0 30 
                 Q ${SCREEN_WIDTH * 0.125} 0, ${SCREEN_WIDTH * 0.25} 15 
                 T ${SCREEN_WIDTH * 0.5} 15 
                 T ${SCREEN_WIDTH * 0.75} 15 
                 T ${SCREEN_WIDTH} 15 
                 Q ${SCREEN_WIDTH * 1.125} 0, ${SCREEN_WIDTH * 1.25} 15 
                 T ${SCREEN_WIDTH * 1.5} 15 
                 T ${SCREEN_WIDTH * 1.75} 15 
                 T ${SCREEN_WIDTH * 2} 15 `;
                
                // Repeat the pattern 20 times to get 40x screen width
                let path = 'M0 30 ';
                for (let i = 0; i < 20; i++) {
                  const offset = i * SCREEN_WIDTH * 2;
                  path += `Q ${offset + SCREEN_WIDTH * 0.125} 0, ${offset + SCREEN_WIDTH * 0.25} 15 
                 T ${offset + SCREEN_WIDTH * 0.5} 15 
                 T ${offset + SCREEN_WIDTH * 0.75} 15 
                 T ${offset + SCREEN_WIDTH} 15 
                 Q ${offset + SCREEN_WIDTH * 1.125} 0, ${offset + SCREEN_WIDTH * 1.25} 15 
                 T ${offset + SCREEN_WIDTH * 1.5} 15 
                 T ${offset + SCREEN_WIDTH * 1.75} 15 
                 T ${offset + SCREEN_WIDTH * 2} 15 `;
                }
                
                // Close the path
                path += `L ${SCREEN_WIDTH * 40} 30 L 0 30 Z`;
                return path;
              })()}
              fill="#B01328"
            />
          </Svg>
        </Animated.View>
      </Animated.View>
    </View>
  );
}

