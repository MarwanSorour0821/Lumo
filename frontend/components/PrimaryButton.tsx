import React from 'react';
import { StyleSheet, Text, View, TouchableOpacity, TouchableOpacityProps } from 'react-native';
import Svg, { Path } from 'react-native-svg';
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

  return (
    <TouchableOpacity 
      style={[styles.button, { backgroundColor: themeColors.button }]}
      onPress={onPress}
      activeOpacity={0.8}
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
    fontWeight: '600',
  },
  arrowContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 4,
  },
});

