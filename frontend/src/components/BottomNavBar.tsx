import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as Haptics from 'expo-haptics';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';

type BottomNavBarProps = {
  currentRoute?: string;
};

// Home Icon
const HomeIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M6.133 21C4.955 21 4 20.02 4 18.81v-8.802c0-.665.295-1.295.8-1.71l5.867-4.818a2.09 2.09 0 0 1 2.666 0l5.866 4.818c.506.415.801 1.045.801 1.71v8.802c0 1.21-.955 2.19-2.133 2.19H6.133Z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M9.5 21v-5.5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2V21"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// My Lab Icon
const MyLabIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 2048 2048" fill="none">
    <Path
      d="M1152 640H512V512h640v128zM256 1664h681l-64 128H128V128h1408v640h-128V256H256v1408zm256-384h617l-64 128H512v-128zm512-384v128H512V896h512zm939 967q14 28 14 57q0 26-10 49t-27 41t-41 28t-50 10h-754q-26 0-49-10t-41-27t-28-41t-10-50q0-29 14-57l299-598v-241h-128V896h640v128h-128v241l299 598zm-242-199l-185-369v-271h-128v271l-185 369h498z"
      fill={color}
    />
  </Svg>
);

// Me Icon (Face/Profile)
const MeIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M.75 12a11.25 11.25 0 1 0 22.5 0a11.25 11.25 0 0 0-22.5 0"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M7.5 17.007a6.68 6.68 0 0 0 9 0M6.75 6.75V9m10.5-2.25V9M12 6.75V12a1.5 1.5 0 0 1-1.5 1.5h-.75"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Chat Icon
const ChatIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Plus Icon
const PlusIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M12 5v14M5 12h14"
      stroke={color}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

export function BottomNavBar({ currentRoute }: BottomNavBarProps) {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const route = useRoute();
  const activeRoute = currentRoute || route.name;

  const leftNavItems = [
    {
      name: 'Home',
      route: 'Home' as keyof RootStackParamList,
      icon: HomeIcon,
    },
    {
      name: 'History',
      route: 'MyLab' as keyof RootStackParamList,
      icon: MyLabIcon,
    },
  ];

  const rightNavItems = [
    {
      name: 'Chat',
      route: 'Chat' as keyof RootStackParamList,
      icon: ChatIcon,
    },
    {
      name: 'Me',
      route: 'Settings' as keyof RootStackParamList,
      icon: MeIcon,
    },
  ];

  const handleNavigate = (routeName: keyof RootStackParamList) => {
    // Trigger haptic feedback on every press
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    
    if (routeName !== activeRoute) {
      navigation.navigate(routeName);
    }
  };

  const handlePlusPress = () => {
    // Trigger haptic feedback
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (activeRoute !== 'Analyse') {
      navigation.navigate('Analyse');
    }
  };

  return (
    <View style={styles.wrapper}>
      <View style={styles.container}>
        {leftNavItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeRoute === item.route;
          
          return (
            <TouchableOpacity
              key={item.route}
              style={[styles.navItem, isActive && styles.navItemActive]}
              onPress={() => handleNavigate(item.route)}
              activeOpacity={0.7}
            >
              <View style={styles.iconContainer}>
                <Icon size={24} color={Colors.white} />
              </View>
              <Text style={[styles.navText, isActive && styles.navTextActive]}>
                {item.name}
              </Text>
            </TouchableOpacity>
          );
        })}
        {/* Plus Button in Center */}
        <TouchableOpacity
          style={styles.plusButton}
          onPress={handlePlusPress}
          activeOpacity={0.7}
        >
          <PlusIcon size={28} color={Colors.white} />
        </TouchableOpacity>
        {rightNavItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeRoute === item.route;
          
          return (
            <TouchableOpacity
              key={item.route}
              style={[styles.navItem, isActive && styles.navItemActive]}
              onPress={() => handleNavigate(item.route)}
              activeOpacity={0.7}
            >
              <View style={styles.iconContainer}>
                <Icon size={24} color={Colors.white} />
              </View>
              <Text style={[styles.navText, isActive && styles.navTextActive]}>
                {item.name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.sm,
    paddingTop: Spacing.xs,
    backgroundColor: Colors.transparent, // Transparent background
  },
  container: {
    flexDirection: 'row',
    backgroundColor: '#1A1A1A', // Very dark gray background
    borderRadius: BorderRadius.xl * 2, // Highly rounded (pill-shaped)
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.sm,
    justifyContent: 'space-around',
    alignItems: 'center',
    minHeight: 64,
  },
  navItem: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    paddingVertical: Spacing.xs + 2,
    paddingHorizontal: Spacing.sm,
    borderRadius: BorderRadius.full, // Pill shape
    marginHorizontal: 2,
  },
  navItemActive: {
    backgroundColor: '#333333', // Lighter gray for active state
    borderRadius: BorderRadius.full, // Fully rounded pill shape
  },
  iconContainer: {
    marginBottom: 4,
  },
  navText: {
    fontSize: FontSize.xs,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  navTextActive: {
    color: Colors.white,
  },
  plusButton: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: Colors.primary,
    marginHorizontal: Spacing.sm,
  },
});

