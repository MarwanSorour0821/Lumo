import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View, Animated, ScrollView, TouchableOpacity, Image, Dimensions } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { PrimaryButton } from '../components';
import { colors, Theme } from '../constants/theme';
import { RootStackParamList } from '../src/types';
import { SignInModal } from '../src/components/SignInModal';
import { signInWithGoogle, getUserProfile } from '../src/lib/supabase';
import { Alert } from 'react-native';
import { usePaywall } from '../src/contexts/PaywallContext';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

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
    borderRadius: 28,
    // Shadow properties - must be on container View, not TouchableOpacity
    elevation: 16,
    shadowColor: '#BB3E4F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.6,
    shadowRadius: 16,
  },
  interactiveButton: {
    width: '100%',
    height: 56,
    borderRadius: 28,
    backgroundColor: '#B01328',
  },
  buttonContent: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
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
  
  // Paywall context
  const { showPaywallForOnboarding } = usePaywall();
  
  // Image slider state
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const scrollViewRef = useRef<ScrollView>(null);
  const images = [
    require('../assets/images/Group 6.png'),
    require('../assets/images/iMockup - iPhone 14.png'),
  ];

  // Sign in modal state
  const [isSignInModalVisible, setIsSignInModalVisible] = useState(false);
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);

  const isProfileComplete = (profile: any | null) => {
    if (!profile) return false;
    const hasSex = !!profile.biological_sex;
    const hasDob = !!profile.date_of_birth;
    const hasHeight = typeof profile.height_cm === 'number';
    const hasWeight = typeof profile.weight_kg === 'number';
    return hasSex && hasDob && hasHeight && hasWeight;
  };

  const continueOrStartSignup = async (
    userId: string,
    userEmail?: string,
    fallbackFirstName?: string,
    fallbackLastName?: string
  ) => {
    const { data: profile } = await getUserProfile(userId);

    if (isProfileComplete(profile)) {
      // Returning user with complete profile - go to Home and show paywall if not shown before
      navigation.reset({ index: 0, routes: [{ name: 'Home' }] });
      // Show paywall for returning users too (will only show once per user)
      await showPaywallForOnboarding(navigation);
      return;
    }

    const signUpData = {
      userId,
      email: profile?.email || userEmail,
      firstName: profile?.first_name || fallbackFirstName,
      lastName: profile?.last_name || fallbackLastName,
      isAppleSignIn: true,
    } as any;

    navigation.navigate('SignUpSex', { signUpData });
  };

  const handleGoogleSignIn = async () => {
    setIsGoogleLoading(true);
    const { data, error } = await signInWithGoogle();

    if (error) {
      if (error.message !== 'Sign in cancelled') {
        Alert.alert('Sign In Error', error.message);
      }
      setIsGoogleLoading(false);
      return;
    }

    if (data.user) {
      await continueOrStartSignup(
        data.user.id,
        data.user.email,
        data.user.firstName,
        data.user.lastName
      );
      setIsGoogleLoading(false);
      setIsSignInModalVisible(false);
    } else {
      setIsGoogleLoading(false);
      Alert.alert('Sign In Error', 'Failed to get user information');
    }
  };

  const handleSignInSuccess = async (userId: string, userEmail?: string) => {
    await continueOrStartSignup(userId, userEmail);
  };

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

  // Handle Get Started button press
  const handleGetStarted = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (onGetStarted) {
      onGetStarted();
    } else {
      navigation.navigate('SignUpSex', {
        signUpData: {} as any,
      });
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
              activeOpacity={0.9}
              onPress={handleGetStarted}
              style={styles.interactiveButton}
            >
              <View style={styles.buttonContent}>
                <Text style={[styles.buttonText, { color: themeColors.buttonText || '#FFFFFF' }]}>
                  Get Started
                </Text>
              </View>
            </TouchableOpacity>
          </View>
          
            <TouchableOpacity
              style={styles.signInLink}
              onPress={() => setIsSignInModalVisible(true)}
              activeOpacity={0.8}
            >
              <Text style={[styles.signInText, { color: themeColors.secondaryText }]}>
                Already have an account?{' '}
                <Text style={[styles.signInTextBold, { color: themeColors.primaryText }]}>Sign in</Text>
              </Text>
            </TouchableOpacity>
          </Animated.View>
        </View>

      {/* Sign In Modal */}
      <SignInModal
        visible={isSignInModalVisible}
        onClose={() => setIsSignInModalVisible(false)}
        onUsePhone={() => {
          setIsSignInModalVisible(false);
          // Handle phone sign-in navigation if needed
          navigation.navigate('Login');
        }}
        onGoogleSignIn={handleGoogleSignIn}
        isGoogleLoading={isGoogleLoading}
        onSignInSuccess={handleSignInSuccess}
      />
    </View>
  );
}

