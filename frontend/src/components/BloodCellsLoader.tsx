import React, { useState, useEffect, useRef } from 'react';
import { View, StyleSheet, Dimensions, Animated } from 'react-native';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const BAR_WIDTH = SCREEN_WIDTH - 40;
const BAR_HEIGHT = 16;

const SimpleRedProgressBar = ({ progress }: { progress?: number }) => {
  const animatedWidth = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (progress !== undefined && progress !== null) {
      // Animate to the new progress value smoothly
      Animated.timing(animatedWidth, {
        toValue: progress,
        duration: 300,
        useNativeDriver: false,
      }).start();
    } else {
      // Indeterminate mode - reset to 0 and start animation
      animatedWidth.setValue(0);
      let currentValue = 0;
      const interval = setInterval(() => {
        currentValue = currentValue >= 100 ? 0 : currentValue + 0.5;
        animatedWidth.setValue(currentValue);
      }, 20);
      return () => clearInterval(interval);
    }
  }, [progress, animatedWidth]);
  const fillWidth = animatedWidth.interpolate({
    inputRange: [0, 100],
    outputRange: [0, BAR_WIDTH],
  });

  return (
    <View style={styles.container}>
      <View style={styles.bar}>
        <Animated.View
          style={[
            styles.fill,
            { width: fillWidth },
          ]}
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    width: '100%',
  },
  bar: {
    position: 'relative',
    width: BAR_WIDTH,
    height: BAR_HEIGHT,
    backgroundColor: 'rgba(176, 19, 40, 0.2)',
    borderRadius: 8,
    overflow: 'hidden',
  },
  fill: {
    position: 'absolute',
    top: 0,
    left: 0,
    height: '100%',
    backgroundColor: '#B01328',
    borderRadius: 8,
  },
});

export default SimpleRedProgressBar;
