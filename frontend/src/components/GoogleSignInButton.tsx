import React from 'react';
import { TouchableOpacity, View, Text, StyleSheet, ActivityIndicator, ViewStyle } from 'react-native';
import Svg, { G, Path } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

interface GoogleSignInButtonProps {
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  text?: string;
  style?: ViewStyle;
}

const GoogleIcon = () => (
  <Svg width={20} height={20} viewBox="0 0 16 16">
    <G fill="none" fillRule="evenodd" clipRule="evenodd">
      <Path
        fill="#F44336"
        d="M7.209 1.061c.725-.081 1.154-.081 1.933 0a6.57 6.57 0 0 1 3.65 1.82a100 100 0 0 0-1.986 1.93q-1.876-1.59-4.188-.734q-1.696.78-2.362 2.528a78 78 0 0 1-2.148-1.658a.26.26 0 0 0-.16-.027q1.683-3.245 5.26-3.86"
        opacity={0.987}
      />
      <Path
        fill="#FFC107"
        d="M1.946 4.92q.085-.013.161.027a78 78 0 0 0 2.148 1.658A7.6 7.6 0 0 0 4.04 7.99q.037.678.215 1.331L2 11.116Q.527 8.038 1.946 4.92"
        opacity={0.997}
      />
      <Path
        fill="#448AFF"
        d="M12.685 13.29a26 26 0 0 0-2.202-1.74q1.15-.812 1.396-2.228H8.122V6.713q3.25-.027 6.497.055q.616 3.345-1.423 6.032a7 7 0 0 1-.51.49"
        opacity={0.999}
      />
      <Path
        fill="#43A047"
        d="M4.255 9.322q1.23 3.057 4.51 2.854a3.94 3.94 0 0 0 1.718-.626q1.148.812 2.202 1.74a6.62 6.62 0 0 1-4.027 1.684a6.4 6.4 0 0 1-1.02 0Q3.82 14.524 2 11.116z"
        opacity={0.993}
      />
    </G>
  </Svg>
);

export default function GoogleSignInButton({
  onPress,
  loading,
  disabled,
  text = 'Continue with Google',
  style,
}: GoogleSignInButtonProps) {
  const isDisabled = disabled || loading;

  return (
    <TouchableOpacity
      style={[styles.button, style]}
      onPress={onPress}
      disabled={isDisabled}
      activeOpacity={0.8}
    >
      {loading ? (
        <ActivityIndicator color={Colors.black} size="small" />
      ) : (
        <View style={styles.content}>
          <View style={styles.iconContainer}>
            <GoogleIcon />
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
