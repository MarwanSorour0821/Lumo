import React, { useEffect, useMemo, useRef } from 'react';
import { View, StyleSheet, Animated } from 'react-native';
import { Colors, Spacing } from '../constants/theme';

interface ProgressBarProps {
  currentStep: number;
  totalSteps: number;
}

export function ProgressBar({ currentStep, totalSteps }: ProgressBarProps) {
  const widthAnims = useMemo(
    () => Array.from({ length: totalSteps }, () => new Animated.Value(8)),
    [totalSteps]
  );

  useEffect(() => {
    widthAnims.forEach((anim, index) => {
      const isActive = index < currentStep;
      const targetWidth = isActive ? 24 : 8;
      
      Animated.spring(anim, {
        toValue: targetWidth,
        useNativeDriver: false,
        tension: 100,
        friction: 8,
      }).start();
    });
  }, [currentStep, widthAnims]);

  return (
    <View style={styles.container}>
      {Array.from({ length: totalSteps }, (_, index) => {
        const isActive = index < currentStep;
        
        return (
          <Animated.View
            key={index}
            style={[
              styles.segment,
              {
                width: widthAnims[index],
                backgroundColor: isActive
                  ? '#B01328'
                  : 'rgba(255, 255, 255, 0.3)',
              },
            ]}
          />
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: Spacing.lg,
  },
  segment: {
    height: 8,
    borderRadius: 4,
  },
});

