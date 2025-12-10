import React from 'react';
import { StyleSheet, Text, View, TouchableOpacity, TouchableOpacityProps } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, Theme } from '../constants/theme';

interface BackButtonProps extends Omit<TouchableOpacityProps, 'style'> {
  theme?: Theme;
  onPress?: () => void;
}

export default function BackButton({ 
  theme = 'dark',
  onPress,
  ...touchableProps
}: BackButtonProps) {
  const themeColors = colors[theme];

  return (
    <TouchableOpacity 
      style={styles.container}
      onPress={onPress}
      activeOpacity={0.7}
      {...touchableProps}
    >
      <Ionicons name="arrow-back" size={24} color={themeColors.primaryText} />
      <Text style={[styles.backText, { color: themeColors.primaryText }]}>
        Back
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  backText: {
    fontSize: 18,
    fontFamily: 'ProductSans-Regular',
  },
});

