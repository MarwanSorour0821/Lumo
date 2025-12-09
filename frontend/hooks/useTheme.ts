import { useColorScheme, Appearance } from 'react-native';
import { useEffect, useState } from 'react';
import { Theme } from '../constants/theme';

/**
 * Hook to get the current theme based on system settings
 * Returns 'dark' or 'light' based on the device's color scheme preference
 */
export const useTheme = (): Theme => {
  const colorScheme = useColorScheme();
  const [theme, setTheme] = useState<Theme>(() => {
    // Get initial theme from Appearance API
    const initialColorScheme = Appearance.getColorScheme();
    return (initialColorScheme === 'dark' ? 'dark' : 'light') as Theme;
  });

  useEffect(() => {
    // Update theme when color scheme changes
    if (colorScheme) {
      setTheme(colorScheme === 'dark' ? 'dark' : 'light');
    }

    // Listen for appearance changes
    const subscription = Appearance.addChangeListener(({ colorScheme: newColorScheme }) => {
      setTheme((newColorScheme === 'dark' ? 'dark' : 'light') as Theme);
    });

    return () => subscription.remove();
  }, [colorScheme]);

  return theme;
};

