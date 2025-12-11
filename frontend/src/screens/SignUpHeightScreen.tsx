import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Animated,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import PrimaryButton from '../../components/PrimaryButton';
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
  
  const [height, setHeight] = useState('');
  const [heightFeet, setHeightFeet] = useState('');
  const [heightInches, setHeightInches] = useState('');
  const [heightUnit, setHeightUnit] = useState<'cm' | 'ft'>('cm');
  const [heightFocused, setHeightFocused] = useState(false);
  const [heightFeetFocused, setHeightFeetFocused] = useState(false);
  const [heightInchesFocused, setHeightInchesFocused] = useState(false);
  const heightBorderAnim = useRef(new Animated.Value(0)).current;
  const heightFeetBorderAnim = useRef(new Animated.Value(0)).current;
  const heightInchesBorderAnim = useRef(new Animated.Value(0)).current;
  const headingFade = useRef(new Animated.Value(0)).current;
  const contentFade = useRef(new Animated.Value(0)).current;
  const buttonFade = useRef(new Animated.Value(0)).current;

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

  useEffect(() => {
    Animated.timing(heightBorderAnim, {
      toValue: heightFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightFocused, heightBorderAnim]);

  useEffect(() => {
    Animated.timing(heightFeetBorderAnim, {
      toValue: heightFeetFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightFeetFocused, heightFeetBorderAnim]);

  useEffect(() => {
    Animated.timing(heightInchesBorderAnim, {
      toValue: heightInchesFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [heightInchesFocused, heightInchesBorderAnim]);

  const handleContinue = () => {
    if (heightUnit === 'cm') {
      const heightNum = parseInt(height, 10);
      if (!height || isNaN(heightNum) || heightNum < 100 || heightNum > 250) {
        Alert.alert('Please enter a valid height between 100 and 250 cm');
        return;
      }
    } else {
      const feetNum = parseInt(heightFeet, 10);
      const inchesNum = parseInt(heightInches, 10);
      if (!heightFeet || isNaN(feetNum) || feetNum < 3 || feetNum > 8) {
        Alert.alert('Please enter a valid height (feet between 3 and 8)');
        return;
      }
      if (!heightInches || isNaN(inchesNum) || inchesNum < 0 || inchesNum >= 12) {
        Alert.alert('Please enter a valid height (inches between 0 and 11)');
        return;
      }
    }
    navigation.navigate('SignUpWeight', { signUpData, sex, age, height, heightFeet, heightInches, heightUnit });
  };

  const borderOpacity = heightBorderAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });
  const feetBorderOpacity = heightFeetBorderAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });
  const inchesBorderOpacity = heightInchesBorderAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });

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
        <ProgressBar currentStep={5} totalSteps={7} />
        
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
                What's your height?
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
              {/* Unit Toggle */}
              <View style={styles.unitToggleContainer}>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    heightUnit === 'cm' && styles.unitToggleActive,
                  ]}
                  onPress={() => setHeightUnit('cm')}
                >
                  <Text
                    style={[
                      styles.unitToggleText,
                      heightUnit === 'cm' && styles.unitToggleTextActive,
                    ]}
                  >
                    cm
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[
                    styles.unitToggle,
                    heightUnit === 'ft' && styles.unitToggleActive,
                  ]}
                  onPress={() => setHeightUnit('ft')}
                >
                  <Text
                    style={[
                      styles.unitToggleText,
                      heightUnit === 'ft' && styles.unitToggleTextActive,
                    ]}
                  >
                    ft/in
                  </Text>
                </TouchableOpacity>
              </View>

              <View style={styles.inputContainer}>
                {heightUnit === 'cm' ? (
                  <View style={{ position: 'relative', width: 200 }}>
                    <TextInput
                      style={styles.textInput}
                      value={height}
                      onChangeText={setHeight}
                      placeholder="170"
                      placeholderTextColor={Colors.dark.textSecondary}
                      keyboardType="numeric"
                      onFocus={() => setHeightFocused(true)}
                      onBlur={() => setHeightFocused(false)}
                    />
                    <View style={[styles.border, { backgroundColor: Colors.dark.border }]} />
                    <Animated.View
                      style={[
                        styles.border,
                        styles.borderAnimated,
                        {
                          backgroundColor: Colors.primary,
                          opacity: borderOpacity,
                        },
                      ]}
                    />
                  </View>
                ) : (
                  <View style={styles.feetInchesContainer}>
                    <View style={styles.feetInchesInputWrapper}>
                      <Text style={styles.unitLabelLeft}>ft</Text>
                      <View style={{ position: 'relative', flex: 1, marginLeft: Spacing.sm }}>
                        <TextInput
                          style={styles.feetInchesInput}
                          value={heightFeet}
                          onChangeText={setHeightFeet}
                          placeholder="5"
                          placeholderTextColor={Colors.dark.textSecondary}
                          keyboardType="numeric"
                          onFocus={() => setHeightFeetFocused(true)}
                          onBlur={() => setHeightFeetFocused(false)}
                        />
                        <View style={[styles.border, { backgroundColor: Colors.dark.border }]} />
                        <Animated.View
                          style={[
                            styles.border,
                            styles.borderAnimated,
                            {
                              backgroundColor: Colors.primary,
                              opacity: feetBorderOpacity,
                            },
                          ]}
                        />
                      </View>
                    </View>
                    <View style={[styles.feetInchesInputWrapper, { marginLeft: Spacing.lg }]}>
                      <Text style={styles.unitLabelLeft}>in</Text>
                      <View style={{ position: 'relative', flex: 1, marginLeft: Spacing.sm }}>
                        <TextInput
                          style={styles.feetInchesInput}
                          value={heightInches}
                          onChangeText={setHeightInches}
                          placeholder="10"
                          placeholderTextColor={Colors.dark.textSecondary}
                          keyboardType="numeric"
                          onFocus={() => setHeightInchesFocused(true)}
                          onBlur={() => setHeightInchesFocused(false)}
                        />
                        <View style={[styles.border, { backgroundColor: Colors.dark.border }]} />
                        <Animated.View
                          style={[
                            styles.border,
                            styles.borderAnimated,
                            {
                              backgroundColor: Colors.primary,
                              opacity: inchesBorderOpacity,
                            },
                          ]}
                        />
                      </View>
                    </View>
                  </View>
                )}
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
  unitToggleContainer: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.xl,
    justifyContent: 'center',
  },
  unitToggle: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    backgroundColor: 'transparent',
  },
  unitToggleActive: {
    borderColor: Colors.primary,
    backgroundColor: 'rgba(176, 19, 40, 0.15)',
  },
  unitToggleText: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
  },
  unitToggleTextActive: {
    color: Colors.primary,
    fontFamily: 'ProductSans-Bold',
  },
  inputContainer: {
    width: '100%',
    alignItems: 'center',
  },
  textInput: {
    width: 200,
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'center',
    paddingVertical: Spacing.xs,
    paddingBottom: 4,
  },
  border: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 1,
  },
  borderAnimated: {
    height: 1,
  },
  feetInchesContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    width: '100%',
    paddingHorizontal: Spacing.xl,
    alignSelf: 'flex-start',
  },
  feetInchesInputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  feetInchesInput: {
    flex: 1,
    fontSize: FontSize.xl,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'left',
    paddingVertical: Spacing.xs,
    paddingBottom: 4,
  },
  unitLabelLeft: {
    fontSize: FontSize.md,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
    minWidth: 30,
  },
  buttonContainer: {
    paddingBottom: Spacing.lg,
  },
});

