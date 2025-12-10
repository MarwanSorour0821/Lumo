import React, { useRef } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, TouchableOpacityProps, Animated } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { colors, Theme } from '../constants/theme';

interface PrimaryButtonProps extends Omit<TouchableOpacityProps, 'style'> {
  text: string;
  theme?: Theme;
  onPress?: () => void;
}

export default function PrimaryButton({ 
  text,
  theme = 'dark',
  onPress,
  ...touchableProps
}: PrimaryButtonProps) {
  const themeColors = colors[theme];
  const scaleAnim = useRef(new Animated.Value(1)).current;

  const handlePressIn = () => {
    // Trigger haptic feedback
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    
    // Scale down animation
    Animated.spring(scaleAnim, {
      toValue: 0.95,
      useNativeDriver: true,
      tension: 300,
      friction: 10,
    }).start();
  };

  const handlePressOut = () => {
    // Scale back to normal
    Animated.spring(scaleAnim, {
      toValue: 1,
      useNativeDriver: true,
      tension: 300,
      friction: 10,
    }).start();
  };

  const handlePress = () => {
    if (onPress) {
      onPress();
    }
  };

  return (
    <Animated.View style={{ transform: [{ scale: scaleAnim }] }}>
      <TouchableOpacity 
        style={[styles.button, { backgroundColor: themeColors.button }]}
        onPress={handlePress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        activeOpacity={1}
        {...touchableProps}
      >
        <Text style={[styles.buttonText, { color: themeColors.buttonText }]}>
          {text}
        </Text>
        <View style={styles.arrowContainer}>
          <Svg width={32} height={32} viewBox="0 0 24 24">
            <Path
              d="m18 12l.354-.354l.353.354l-.353.354zm-12 .5a.5.5 0 0 1 0-1zm8.354-4.854l4 4l-.708.708l-4-4zm4 4.708l-4 4l-.708-.708l4-4zM18 12.5H6v-1h12z"
              fill={themeColors.buttonText}
            />
          </Svg>
        </View>
      </TouchableOpacity>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 9999,
  },
  buttonText: {
    fontSize: 18,
    fontFamily: 'ProductSans-Bold',
  },
  arrowContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 4,
  },
});

