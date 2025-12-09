import React, { useState } from 'react';
import {
  View,
  TextInput,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
} from 'react-native';
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
}: InputProps) {
  const [isSecure, setIsSecure] = useState(secureTextEntry);
  const [isFocused, setIsFocused] = useState(false);
  
  return (
    <View style={[styles.container, style]}>
      <Text style={[styles.label, { color: isDark ? Colors.dark.text : Colors.light.text }]}>
        {label}
      </Text>
      <View
        style={[
          styles.inputContainer,
          {
            borderColor: error
              ? Colors.error
              : isFocused
              ? Colors.primary
              : isDark
              ? Colors.dark.border
              : Colors.light.border,
            backgroundColor: isDark ? Colors.dark.inputBackground : Colors.light.inputBackground,
          },
        ]}
      >
        <TextInput
          style={[styles.input, { color: isDark ? Colors.dark.text : Colors.light.text }]}
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
          >
            <Text style={{ color: isDark ? Colors.dark.textSecondary : Colors.light.textSecondary }}>
              {isSecure ? '👁' : '👁‍🗨'}
            </Text>
          </TouchableOpacity>
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
  input: {
    flex: 1,
    fontSize: FontSize.md,
    paddingVertical: Spacing.sm,
  },
  eyeButton: {
    padding: Spacing.sm,
  },
  errorText: {
    color: Colors.error,
    fontSize: FontSize.xs,
    marginTop: Spacing.xs,
    marginLeft: Spacing.md,
  },
});

