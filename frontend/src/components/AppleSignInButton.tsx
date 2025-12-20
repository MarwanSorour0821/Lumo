import React from 'react';
import { TouchableOpacity, View, Text, StyleSheet, ActivityIndicator, ViewStyle, Platform } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Haptics from 'expo-haptics';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

const AppleIcon = () => (
  <Svg width={20} height={20} viewBox="0 0 24 24">
    <Path
      fill={Colors.black}
      d="M14.94 5.19A4.38 4.38 0 0 0 16 2a4.44 4.44 0 0 0-3 1.52a4.17 4.17 0 0 0-1 3.09a3.69 3.69 0 0 0 2.94-1.42Zm2.52 7.44a4.51 4.51 0 0 1 2.16-3.81a4.66 4.66 0 0 0-3.66-2c-1.56-.16-3 .91-3.83.91s-2-.89-3.3-.87a4.92 4.92 0 0 0-4.14 2.53C2.93 12.45 4.24 17 6 19.47c.8 1.21 1.8 2.58 3.12 2.53s1.75-.82 3.28-.82s2 .82 3.3.79s2.22-1.24 3.06-2.45a11 11 0 0 0 1.38-2.85a4.41 4.41 0 0 1-2.68-4.04Z"
    />
  </Svg>
);

interface AppleSignInButtonProps {
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  text?: string;
  style?: ViewStyle;
}

export default function AppleSignInButton({
  onPress,
  loading,
  disabled,
  text = 'Continue with Apple',
  style,
}: AppleSignInButtonProps) {
  const isDisabled = disabled || loading;

  const handlePress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (onPress) {
      onPress();
    }
  };

  // Only show on iOS
  if (Platform.OS !== 'ios') {
    return null;
  }

  // Use custom white button to match Google button style
  return (
    <TouchableOpacity
      style={[styles.button, style]}
      onPress={handlePress}
      disabled={isDisabled}
      activeOpacity={0.8}
    >
      {loading ? (
        <ActivityIndicator color={Colors.black} size="small" />
      ) : (
        <View style={styles.content}>
          <View style={styles.iconContainer}>
            <AppleIcon />
          </View>
          <Text style={styles.text}>{text}</Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    backgroundColor: Colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
  },
  iconContainer: {
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Bold',
    color: Colors.black,
  },
});


