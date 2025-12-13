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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Picker } from '@react-native-picker/picker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import PrimaryButton from '../../components/PrimaryButton';
import BackButton from '../../components/BackButton';
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
        <View style={styles.headerContainer}>
          <BackButton
            onPress={() => navigation.goBack()}
            theme="dark"
          />
        </View>
        <ProgressBar currentStep={4} totalSteps={7} />
        
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


