import React, { useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Dimensions,
  NativeSyntheticEvent,
  NativeScrollEvent,
  ViewStyle,
} from 'react-native';
import { Colors, FontSize, FontWeight } from '../constants/theme';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const ITEM_HEIGHT = 50;
const VISIBLE_ITEMS = 5;

interface WheelPickerProps {
  data: (string | number)[];
  selectedIndex: number;
  onSelect: (index: number) => void;
  suffix?: string;
  style?: ViewStyle;
  isDark?: boolean;
}

export function WheelPicker({
  data,
  selectedIndex,
  onSelect,
  suffix = '',
  style,
  isDark = true,
}: WheelPickerProps) {
  const flatListRef = useRef<FlatList>(null);
  
  const paddedData = ['', '', ...data, '', ''];
  
  const handleMomentumScrollEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const offsetY = event.nativeEvent.contentOffset.y;
      const index = Math.round(offsetY / ITEM_HEIGHT);
      if (index >= 0 && index < data.length) {
        onSelect(index);
      }
    },
    [data.length, onSelect]
  );
  
  const renderItem = ({ item, index }: { item: string | number; index: number }) => {
    const actualIndex = index - 2;
    const isSelected = actualIndex === selectedIndex;
    const distance = Math.abs(actualIndex - selectedIndex);
    
    let opacity = 1;
    let scale = 1;
    
    if (distance === 1) {
      opacity = 0.5;
      scale = 0.9;
    } else if (distance === 2) {
      opacity = 0.25;
      scale = 0.8;
    } else if (distance > 2) {
      opacity = 0;
    }
    
    if (item === '') {
      return <View style={styles.item} />;
    }
    
    return (
      <View style={[styles.item, { opacity }]}>
        <Text
          style={[
            styles.itemText,
            {
              color: isSelected ? Colors.primary : Colors.dark.text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.regular,
              transform: [{ scale }],
            },
          ]}
        >
          {item}{suffix && isSelected ? ` ${suffix}` : ''}
        </Text>
      </View>
    );
  };
  
  return (
    <View style={[styles.container, style]}>
      <View pointerEvents="none" style={[styles.selectedOverlay, { borderColor: Colors.primary }]} />
      <FlatList
        ref={flatListRef}
        data={paddedData}
        renderItem={renderItem}
        keyExtractor={(_, index) => index.toString()}
        showsVerticalScrollIndicator={false}
        snapToInterval={ITEM_HEIGHT}
        decelerationRate={0.99}
        onMomentumScrollEnd={handleMomentumScrollEnd}
        getItemLayout={(_, index) => ({
          length: ITEM_HEIGHT,
          offset: ITEM_HEIGHT * index,
          index,
        })}
        initialScrollIndex={selectedIndex}
        contentContainerStyle={styles.contentContainer}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: ITEM_HEIGHT * VISIBLE_ITEMS,
  },
  contentContainer: {
    paddingVertical: 0,
  },
  item: {
    height: ITEM_HEIGHT,
    justifyContent: 'center',
    alignItems: 'center',
  },
  itemText: {
    fontSize: FontSize.xl,
  },
  selectedOverlay: {
    position: 'absolute',
    top: ITEM_HEIGHT * 2,
    left: 0,
    right: 0,
    height: ITEM_HEIGHT,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: Colors.primary,
    zIndex: 1,
  },
});

