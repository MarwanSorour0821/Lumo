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
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
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
  const maleScale = useRef(new Animated.Value(1)).current;
  const femaleScale = useRef(new Animated.Value(1)).current;
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

  useEffect(() => {
    if (sex === 'male') {
      Animated.spring(maleScale, {
        toValue: 1.05,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }).start();
      Animated.spring(femaleScale, {
        toValue: 1,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }).start();
    } else if (sex === 'female') {
      Animated.spring(femaleScale, {
        toValue: 1.05,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }).start();
      Animated.spring(maleScale, {
        toValue: 1,
        useNativeDriver: true,
        tension: 300,
        friction: 10,
      }).start();
    }
  }, [sex]);

  const handleContinue = () => {
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
        <View style={styles.headerContainer}>
          <BackButton
            onPress={() => navigation.goBack()}
            theme="dark"
          />
        </View>
        <ProgressBar currentStep={3} totalSteps={7} />
        
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
                Your Sex
              </Animated.Text>
              
              <Animated.Text 
                style={[
                  styles.subtitle,
                  {
                    opacity: headingFade,
                  }
                ]}
              >
                Select your biological sex
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
                <TouchableOpacity
                  activeOpacity={0.8}
                  onPress={() => {
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    setSex('male');
                  }}
                >
                  <Animated.View
                    style={[
                      styles.sexOption,
                      sex === 'male' && styles.sexOptionSelected,
                      {
                        transform: [{ scale: maleScale }],
                      },
                    ]}
                  >
                    <Text style={styles.sexIcon}>♂</Text>
                    <Text
                      style={[
                        styles.sexLabel,
                        sex === 'male' && styles.sexLabelSelected,
                      ]}
                    >
                      Male
                    </Text>
                  </Animated.View>
                </TouchableOpacity>
                
                <TouchableOpacity
                  activeOpacity={0.8}
                  onPress={() => {
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                    setSex('female');
                  }}
                >
                  <Animated.View
                    style={[
                      styles.sexOption,
                      sex === 'female' && styles.sexOptionSelected,
                      {
                        transform: [{ scale: femaleScale }],
                      },
                    ]}
                  >
                    <Text style={styles.sexIcon}>♀</Text>
                    <Text
                      style={[
                        styles.sexLabel,
                        sex === 'female' && styles.sexLabelSelected,
                      ]}
                    >
                      Female
                    </Text>
                  </Animated.View>
                </TouchableOpacity>
              </View>
            </Animated.View>

            <Animated.View
              style={[
                styles.buttonContainer,
                {
                  opacity: buttonFade,
                }
              ]}
            >
              <PrimaryButton
                text="Continue"
                onPress={handleContinue}
                disabled={!sex}
                theme="dark"
              />
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
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
  },
  sexOptions: {
    flexDirection: 'row',
    gap: Spacing.lg,
    justifyContent: 'center',
  },
  sexOption: {
    width: 120,
    height: 140,
    borderRadius: BorderRadius.lg,
    borderWidth: 2,
    borderColor: Colors.dark.border,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
  },
  sexOptionSelected: {
    borderColor: Colors.primary,
    backgroundColor: 'rgba(176, 19, 40, 0.15)',
  },
  sexIcon: {
    fontSize: 48,
    color: Colors.white,
    marginBottom: Spacing.sm,
  },
  sexLabel: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
  sexLabelSelected: {
    color: Colors.primary,
    fontFamily: 'ProductSans-Bold',
  },
  buttonContainer: {
    paddingBottom: Spacing.lg,
  },
});


