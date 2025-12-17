import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { AnalyseScreen } from './AnalyseScreen';
import { Colors } from '../constants/theme';

export function AnalyseScreenWrapper() {
  const [modalVisible, setModalVisible] = useState(false);

  useFocusEffect(
    React.useCallback(() => {
      // Show modal when screen is focused
      setModalVisible(true);
      return () => {
        // Hide modal when screen loses focus
        setModalVisible(false);
      };
    }, [])
  );

  const handleClose = () => {
    setModalVisible(false);
  };

  return (
    <View style={styles.container}>
      <AnalyseScreen visible={modalVisible} onClose={handleClose} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
});

