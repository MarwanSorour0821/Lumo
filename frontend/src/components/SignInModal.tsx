import React, { useState, useEffect, useRef } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  Platform,
  Dimensions,
  ScrollView,
  Keyboard,
  Animated,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Path } from 'react-native-svg';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import * as Haptics from 'expo-haptics';
import * as WebBrowser from 'expo-web-browser';
import { Alert } from 'react-native';
import GoogleSignInButton from './GoogleSignInButton';
import { signInWithEmail } from '../lib/supabase';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface SignInModalProps {
  visible: boolean;
  onClose: () => void;
  onContinue?: (email: string) => void;
  onUsePhone?: () => void;
  onGoogleSignIn?: () => void;
  isGoogleLoading?: boolean;
  onSignInSuccess?: (userId: string, email?: string) => void;
}

export function SignInModal({ visible, onClose, onContinue, onUsePhone, onGoogleSignIn, isGoogleLoading = false, onSignInSuccess }: SignInModalProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const heightAnim = useRef(new Animated.Value(SCREEN_HEIGHT * 0.65)).current;
  const backdropOpacity = useRef(new Animated.Value(0)).current;

  // Reset form when modal closes
  useEffect(() => {
    if (!visible) {
      setEmail('');
      setPassword('');
      setShowPassword(false);
    }
  }, [visible]);

  useEffect(() => {
    if (visible) {
      Animated.timing(backdropOpacity, {
        toValue: 1,
        duration: 500,
        easing: (t) => t * (2 - t), // ease-out easing
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(backdropOpacity, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  }, [visible, backdropOpacity]);

  useEffect(() => {
    const keyboardWillShow = Keyboard.addListener(
      Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow',
      (e) => {
        const newHeight = Math.min(
          SCREEN_HEIGHT * 0.65 + e.endCoordinates.height,
          SCREEN_HEIGHT * 0.9
        );
        setKeyboardHeight(e.endCoordinates.height);
        Animated.timing(heightAnim, {
          toValue: newHeight,
          duration: Platform.OS === 'ios' ? 250 : 200,
          useNativeDriver: false,
        }).start();
      }
    );
    const keyboardWillHide = Keyboard.addListener(
      Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide',
      () => {
        setKeyboardHeight(0);
        Animated.timing(heightAnim, {
          toValue: SCREEN_HEIGHT * 0.65,
          duration: Platform.OS === 'ios' ? 250 : 200,
          useNativeDriver: false,
        }).start();
      }
    );

    return () => {
      keyboardWillShow.remove();
      keyboardWillHide.remove();
    };
  }, [heightAnim]);

  const handleContinue = async () => {
    if (!email.trim()) {
      Alert.alert('Error', 'Please enter your email address');
      return;
    }

    if (!showPassword) {
      // Show password field
      setShowPassword(true);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      return;
    }

    if (!password.trim()) {
      Alert.alert('Error', 'Please enter your password');
      return;
    }

    // Sign in with email and password
    setIsLoading(true);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    
    const { data, error } = await signInWithEmail(email.trim(), password);

    setIsLoading(false);

    if (error) {
      Alert.alert('Sign In Error', error.message);
      return;
    }

    if (data.user) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      if (onSignInSuccess) {
        onSignInSuccess(data.user.id, data.user.email || email.trim());
      }
      onClose();
    } else {
      Alert.alert('Sign In Error', 'Unable to sign in. Please try again.');
    }
  };

  const handleClose = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onClose();
  };

  const handleTermsPress = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await WebBrowser.openBrowserAsync('https://www.lumo-blood.com/terms-of-use', {
      presentationStyle: WebBrowser.WebBrowserPresentationStyle.FORM_SHEET,
    });
  };

  const handlePrivacyPress = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await WebBrowser.openBrowserAsync('https://www.lumo-blood.com/privacy-policy', {
      presentationStyle: WebBrowser.WebBrowserPresentationStyle.FORM_SHEET,
    });
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={handleClose}
    >
      <View style={styles.container}>
        {/* Backdrop */}
        <Animated.View
          style={[
            styles.backdrop,
            { opacity: backdropOpacity }
          ]}
        >
          <TouchableOpacity
            style={StyleSheet.absoluteFill}
            activeOpacity={1}
            onPress={handleClose}
          />
        </Animated.View>

        {/* Modal Content */}
        <Animated.View style={[
          styles.modalContent,
          { 
            height: heightAnim
          }
        ]}>
            {/* Drag Handle */}
            <View style={styles.dragHandle} />

            {/* Close Button */}
            <TouchableOpacity
              style={styles.closeButton}
              onPress={handleClose}
              activeOpacity={0.7}
            >
            <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
              <Path
                d="M18 6L6 18M6 6l12 12"
                stroke="#FFFFFF"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </Svg>
            </TouchableOpacity>

            <ScrollView
              style={styles.scrollView}
              contentContainerStyle={styles.scrollContent}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
            >
            {/* Envelope Icon */}
            <View style={styles.iconContainer}>
              <Svg width={30} height={30} viewBox="0 0 20 20">
                <Path
                  fill="#B01328"
                  fillRule="evenodd"
                  d="m7.172 11.334l2.83 1.935l2.728-1.882l6.115 6.033c-.161.052-.333.08-.512.08H1.667c-.22 0-.43-.043-.623-.12l6.128-6.046ZM20 6.376v9.457c0 .247-.054.481-.15.692l-5.994-5.914L20 6.376ZM0 6.429l6.042 4.132l-5.936 5.858A1.663 1.663 0 0 1 0 15.833V6.43ZM18.333 2.5c.92 0 1.667.746 1.667 1.667v.586L9.998 11.648L0 4.81v-.643C0 3.247.746 2.5 1.667 2.5h16.666Z"
                />
              </Svg>
            </View>

            {/* Title */}
            <Text style={styles.title}>Sign In</Text>

            {/* Email Input Field */}
            <View style={styles.inputContainer}>
              <View style={styles.inputWrapper}>
                <View style={styles.inputIconContainer}>
                  <Svg width={20} height={20} viewBox="0 0 24 24" fill="none">
                    <Path
                      d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"
                      stroke="#808080"
                      strokeWidth="1.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                    <Path
                      d="M22 6l-10 7L2 6"
                      stroke="#808080"
                      strokeWidth="1.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </Svg>
                </View>
                <TextInput
                  style={styles.input}
                  placeholder="Email address"
                  placeholderTextColor="#808080"
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoCorrect={false}
                  textContentType="emailAddress"
                  editable={!showPassword}
                />
              </View>
            </View>

            {/* Password Input Field */}
            {showPassword && (
              <View style={styles.inputContainer}>
                <View style={styles.inputWrapper}>
                  <View style={styles.inputIconContainer}>
                    <Svg width={20} height={20} viewBox="0 0 24 24" fill="none">
                      <Path
                        d="M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z"
                        stroke="#808080"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                      <Path
                        d="M7 11V7a5 5 0 0 1 10 0v4"
                        stroke="#808080"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </Svg>
                  </View>
                  <TextInput
                    style={styles.input}
                    placeholder="Password"
                    placeholderTextColor="#808080"
                    value={password}
                    onChangeText={setPassword}
                    secureTextEntry
                    autoCapitalize="none"
                    autoCorrect={false}
                    textContentType="password"
                  />
                </View>
              </View>
            )}

            {/* Google Sign In Button */}
            {onGoogleSignIn && (
              <View style={styles.googleButtonContainer}>
                <GoogleSignInButton
                  onPress={() => {
                    if (onGoogleSignIn) {
                      onGoogleSignIn();
                    }
                  }}
                  loading={isGoogleLoading}
                  style={styles.googleButton}
                />
              </View>
            )}

            {/* Continue Button */}
            <TouchableOpacity
              style={styles.continueButton}
              onPress={handleContinue}
              activeOpacity={0.9}
              disabled={isLoading}
            >
              <LinearGradient
                colors={[Colors.primary, Colors.primaryLight]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={styles.continueButtonGradient}
              >
                <Text style={styles.continueButtonText}>
                  {isLoading ? 'Signing in...' : showPassword ? 'Sign In' : 'Continue'}
                </Text>
                <Svg width={20} height={20} viewBox="0 0 24 24" fill="none">
                  <Path
                    d="M5 12h14M12 5l7 7-7 7"
                    stroke="white"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </Svg>
              </LinearGradient>
            </TouchableOpacity>

            {/* Terms Disclaimer */}
            <Text style={styles.disclaimer}>
              By continuing, you agree to the{'\n'}
              <Text style={styles.linkText} onPress={handleTermsPress}>
                Terms of Use
              </Text>
              {' and '}
              <Text style={styles.linkText} onPress={handlePrivacyPress}>
                Privacy Policy
              </Text>
            </Text>
          </ScrollView>
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: Colors.dark.surface,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    width: '100%',
    height: SCREEN_HEIGHT * 0.65,
    paddingTop: 12,
    paddingBottom: Platform.OS === 'ios' ? 40 : 24,
    overflow: 'hidden',
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
  },
  dragHandle: {
    width: 40,
    height: 4,
    backgroundColor: Colors.dark.border,
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 20,
  },
  closeButton: {
    position: 'absolute',
    top: 16,
    right: 16,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.dark.surface,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  iconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 18,
    marginBottom: 15,
  },
  title: {
    fontSize: 22,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 32,
  },
  googleButtonContainer: {
    marginBottom: 10,
    width: '100%',
  },
  googleButton: { // Match Continue button height (16px padding * 2 + content)
    paddingVertical: 14,
  },
  inputContainer: {
    marginBottom: 24,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.dark.background,
    borderRadius: 28,
    paddingHorizontal: 16,
    minHeight: 56,
  },
  inputIconContainer: {
    marginRight: 12,
  },
  input: {
    flex: 1,
    fontSize: 16,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    paddingVertical: 0,
  },
  continueButton: {
    borderRadius: 28,
    overflow: 'hidden',
    marginBottom: 16,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  continueButtonGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    paddingHorizontal: 24,
    gap: 8,
  },
  continueButtonText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    color: '#FFFFFF',
  },
  disclaimer: {
    fontSize: 14,
    fontFamily: 'ProductSans-Regular',
    color: '#808080',
    textAlign: 'center',
    lineHeight: 16,
    paddingHorizontal: 16,
  },
  linkText: {
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    color: '#FFFFFF',
    
  },
});

