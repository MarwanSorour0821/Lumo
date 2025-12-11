import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  TextInput,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  Animated,
} from 'react-native';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, BorderRadius, FontSize, Spacing } from '../constants/theme';

interface InputProps {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  secureTextEntry?: boolean;
  keyboardType?: 'default' | 'email-address' | 'numeric' | 'phone-pad';
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  error?: string;
  style?: ViewStyle;
  isDark?: boolean;
  variant?: 'default' | 'underline';
}

export function Input({
  label,
  value,
  onChangeText,
  placeholder,
  secureTextEntry = false,
  keyboardType = 'default',
  autoCapitalize = 'none',
  error,
  style,
  isDark = true,
  variant = 'default',
}: InputProps) {
  const [isSecure, setIsSecure] = useState(secureTextEntry);
  const [isFocused, setIsFocused] = useState(false);
  const borderAnim = useRef(new Animated.Value(0)).current;
  const eyeIconAnim = useRef(new Animated.Value(isSecure ? 1 : 0)).current;
  
  const isUnderline = variant === 'underline';
  
  useEffect(() => {
    Animated.timing(borderAnim, {
      toValue: isFocused ? 1 : 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [isFocused, borderAnim]);

  useEffect(() => {
    Animated.timing(eyeIconAnim, {
      toValue: isSecure ? 1 : 0,
      duration: 200,
      useNativeDriver: true,
    }).start();
  }, [isSecure, eyeIconAnim]);

  const defaultBorderColor = isUnderline 
    ? Colors.dark.border 
    : (isDark ? Colors.dark.border : Colors.light.border);
  const focusedBorderColor = Colors.primary;
  
  const borderOpacity = borderAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });
  
  return (
    <View style={[styles.container, style]}>
      <Text style={[
        isUnderline ? styles.underlineLabel : styles.label,
        { color: isDark ? (isUnderline ? Colors.dark.textSecondary : Colors.dark.text) : (isUnderline ? Colors.light.textSecondary : Colors.light.text) }
      ]}>
        {label}
      </Text>
      <View style={{ position: 'relative' }}>
        <View
          style={[
            isUnderline ? styles.underlineInputContainer : styles.inputContainer,
            {
              borderColor: error ? Colors.error : defaultBorderColor,
              borderBottomColor: error ? Colors.error : defaultBorderColor,
              borderTopWidth: isUnderline ? 0 : 1,
              borderLeftWidth: isUnderline ? 0 : 1,
              borderRightWidth: isUnderline ? 0 : 1,
              borderBottomWidth: 1,
              backgroundColor: isUnderline ? 'transparent' : (isDark ? Colors.dark.inputBackground : Colors.light.inputBackground),
            },
          ]}
        >
          <TextInput
            style={[styles.input, isUnderline && styles.underlineInput, { color: isDark ? Colors.dark.text : Colors.light.text }]}
            value={value}
            onChangeText={onChangeText}
            placeholder={placeholder}
            placeholderTextColor={isDark ? Colors.dark.textSecondary : Colors.light.textSecondary}
            secureTextEntry={isSecure}
            keyboardType={keyboardType}
            autoCapitalize={autoCapitalize}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
          />
          {secureTextEntry && (
            <TouchableOpacity
              onPress={() => setIsSecure(!isSecure)}
              style={styles.eyeButton}
              activeOpacity={0.7}
            >
              <View style={styles.eyeIconContainer}>
                <Animated.View
                  style={[
                    styles.eyeIcon,
                    {
                      opacity: eyeIconAnim.interpolate({
                        inputRange: [0, 1],
                        outputRange: [0, 1],
                      }),
                      transform: [
                        {
                          scale: eyeIconAnim.interpolate({
                            inputRange: [0, 1],
                            outputRange: [0.8, 1],
                          }),
                        },
                      ],
                    },
                  ]}
                >
                  <Svg width={20} height={20} viewBox="0 0 512 512">
                    <Path
                      fill={isDark ? Colors.dark.textSecondary : Colors.light.textSecondary}
                      fillRule="evenodd"
                      d="m89.752 59.582l138.656 138.656C236.763 194.239 246.12 192 256 192c35.346 0 64 28.654 64 64c0 9.881-2.239 19.239-6.237 27.594l138.656 138.655l-30.17 30.17l-59.207-59.208c-29.128 19.7-64.646 33.456-107.042 33.456C106.667 426.667 42.667 256 42.667 256s22.862-60.965 73.14-110.02L59.583 89.751zm56.355 116.695c-28.73 27.818-47.477 60.904-56.726 79.73C107.404 292.697 161.739 384 256 384c29.106 0 54.406-8.706 76.006-21.823l-48.414-48.414C275.238 317.761 265.881 320 256 320c-35.346 0-64-28.654-64-64c0-9.88 2.24-19.238 6.238-27.592ZM256 85.334C405.334 85.334 469.334 256 469.334 256s-14.239 37.97-44.955 78.09l-30.56-30.567c13.43-18.244 22.99-35.702 28.802-47.53C404.597 219.302 350.262 128 256.001 128c-11.838 0-23.046 1.44-33.631 4.031l-34.04-34.049c20.25-7.905 42.775-12.648 67.67-12.648"
                    />
                  </Svg>
                </Animated.View>
                <Animated.View
                  style={[
                    styles.eyeIcon,
                    {
                      position: 'absolute',
                      opacity: eyeIconAnim.interpolate({
                        inputRange: [0, 1],
                        outputRange: [1, 0],
                      }),
                      transform: [
                        {
                          scale: eyeIconAnim.interpolate({
                            inputRange: [0, 1],
                            outputRange: [1, 0.8],
                          }),
                        },
                      ],
                    },
                  ]}
                >
                  <Svg width={20} height={20} viewBox="0 0 24 24">
                    <G
                      fill="none"
                      stroke={isDark ? Colors.dark.textSecondary : Colors.light.textSecondary}
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                    >
                      <Path d="M21.257 10.962c.474.62.474 1.457 0 2.076C19.764 14.987 16.182 19 12 19c-4.182 0-7.764-4.013-9.257-5.962a1.692 1.692 0 0 1 0-2.076C4.236 9.013 7.818 5 12 5c4.182 0 7.764 4.013 9.257 5.962Z" />
                      <Circle cx="12" cy="12" r="3" />
                    </G>
                  </Svg>
                </Animated.View>
              </View>
            </TouchableOpacity>
          )}
        </View>
        {isUnderline && !error && (
          <Animated.View
            style={[
              styles.animatedBorder,
              {
                backgroundColor: focusedBorderColor,
                opacity: borderOpacity,
              },
            ]}
          />
        )}
      </View>
      {error && <Text style={styles.errorText}>{error}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: Spacing.md,
  },
  label: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    marginBottom: Spacing.sm,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: BorderRadius.full,
    paddingHorizontal: Spacing.md,
    minHeight: 52,
  },
  underlineInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingBottom: 0,
    minHeight: 52,
  },
  animatedBorder: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 1,
  },
  input: {
    flex: 1,
    fontSize: FontSize.md,
    paddingVertical: Spacing.sm,
  },
  underlineInput: {
    paddingVertical: Spacing.xs,
    paddingBottom: 0,
    fontSize: FontSize.lg,
  },
  underlineLabel: {
    fontSize: FontSize.sm,
    marginBottom: Spacing.sm,
  },
  eyeButton: {
    padding: Spacing.sm,
  },
  eyeIconContainer: {
    width: 20,
    height: 20,
    position: 'relative',
  },
  eyeIcon: {
    width: 20,
    height: 20,
  },
  errorText: {
    color: Colors.error,
    fontSize: FontSize.xs,
    marginTop: Spacing.xs,
    marginLeft: Spacing.md,
  },
});

