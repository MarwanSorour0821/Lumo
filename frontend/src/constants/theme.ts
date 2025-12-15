export const Colors = {
  primary: '#C7002B', // Vibrant red from image
  primaryDark: '#8E0F20',
  primaryLight: '#D4283D',
  
  // Always use dark mode colors
  background: '#000000', // Pure black from image
  surface: '#1A1A1A', // Dark grey for search bar and test items
  text: '#FFFFFF',
  textSecondary: '#808080', // Medium grey for placeholder and sub-text
  border: '#333333',
  inputBackground: 'rgba(255, 255, 255, 0.08)',
  
  // Legacy dark object for backward compatibility
  dark: {
    background: '#000000',
    surface: '#1A1A1A',
    text: '#FFFFFF',
    textSecondary: '#808080',
    border: '#333333',
    inputBackground: 'rgba(255, 255, 255, 0.08)',
  },
  
  white: '#FFFFFF',
  black: '#000000',
  transparent: 'transparent',
  error: '#FF4444',
  success: '#44BB44',
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const BorderRadius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 9999,
};

export const FontSize = {
  xs: 12,
  sm: 14,
  md: 16,
  lg: 18,
  xl: 24,
  xxl: 32,
  xxxl: 40,
};

export const FontWeight = {
  regular: '400' as const,
  medium: '500' as const,
  semibold: '600' as const,
  bold: '700' as const,
};

export function useThemeColors() {
  // Always return dark mode colors
  return {
    isDark: true,
    colors: Colors.dark,
    primary: Colors.primary,
  };
}

