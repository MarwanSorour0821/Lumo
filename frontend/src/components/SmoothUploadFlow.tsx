import React, { useState, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Animated, Easing, Modal, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface UploadFlowProps {
  onTakePhoto: () => void;
  onPickImage: () => void;
  onPickDocument: () => void;
  selectedFile: string | null;
  fileType: 'image' | 'pdf' | null;
}

export const SmoothUploadFlow: React.FC<UploadFlowProps> = ({
  onTakePhoto,
  onPickImage,
  onPickDocument,
  selectedFile,
  fileType,
}) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const backdropOpacity = useRef(new Animated.Value(0)).current;
  const menuScale = useRef(new Animated.Value(0)).current;
  const menuOpacity = useRef(new Animated.Value(0)).current;
  const checkScale = useRef(new Animated.Value(0)).current;
  const checkRotate = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (isMenuOpen) {
      // Reset animated values to 0 to ensure animation always starts from beginning
      backdropOpacity.setValue(0);
      menuScale.setValue(0);
      menuOpacity.setValue(0);
      
      // Small delay to ensure reset is applied before animation starts
      requestAnimationFrame(() => {
        // Open popup animation
        Animated.parallel([
          Animated.timing(backdropOpacity, {
            toValue: 1,
            duration: 200,
            easing: Easing.out(Easing.ease),
            useNativeDriver: true,
          }),
          Animated.parallel([
            Animated.spring(menuScale, {
              toValue: 1,
              tension: 50,
              friction: 7,
              useNativeDriver: true,
            }),
            Animated.timing(menuOpacity, {
              toValue: 1,
              duration: 250,
              easing: Easing.out(Easing.ease),
              useNativeDriver: true,
            }),
          ]),
        ]).start();
      });
    } else {
      // Close popup animation
      Animated.parallel([
        Animated.timing(backdropOpacity, {
          toValue: 0,
          duration: 150,
          easing: Easing.in(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.parallel([
          Animated.timing(menuScale, {
            toValue: 0,
            duration: 200,
            easing: Easing.in(Easing.ease),
            useNativeDriver: true,
          }),
          Animated.timing(menuOpacity, {
            toValue: 0,
            duration: 150,
            easing: Easing.in(Easing.ease),
            useNativeDriver: true,
          }),
        ]),
      ]).start();
    }
  }, [isMenuOpen]);

  useEffect(() => {
    if (selectedFile) {
      // Success animation
      Animated.sequence([
        Animated.parallel([
          Animated.spring(checkScale, {
            toValue: 1,
            tension: 50,
            friction: 7,
            useNativeDriver: true,
          }),
          Animated.timing(checkRotate, {
            toValue: 1,
            duration: 400,
            easing: Easing.out(Easing.back(1.5)),
            useNativeDriver: true,
          }),
        ]),
      ]).start();
    } else {
      checkScale.setValue(0);
      checkRotate.setValue(0);
    }
  }, [selectedFile]);

  const handleOptionPress = (action: () => void) => {
    setIsMenuOpen(false);
    setTimeout(() => {
      action();
    }, 200);
  };

  const handleBackdropPress = () => {
    setIsMenuOpen(false);
  };

  const checkRotation = checkRotate.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  return (
    <View style={styles.container}>
      {/* Upload Button */}
      <TouchableOpacity
        style={[
          styles.uploadButton,
          selectedFile && styles.uploadButtonSuccess,
        ]}
        onPress={() => !selectedFile && setIsMenuOpen(!isMenuOpen)}
        disabled={!!selectedFile}
      >
        {selectedFile ? (
          <>
            <Animated.View
              style={{
                transform: [
                  { scale: checkScale },
                  { rotate: checkRotation },
                ],
              }}
            >
              <Ionicons name="checkmark-circle" size={24} color={Colors.primary} />
            </Animated.View>
            <Text style={styles.uploadButtonTextSuccess}>
              {fileType === 'pdf' ? 'PDF' : 'Image'} Selected
            </Text>
          </>
        ) : (
          <>
            <Ionicons name="cloud-upload-outline" size={20} color={Colors.white} />
            <Text style={styles.uploadButtonText}>Upload</Text>
          </>
        )}
      </TouchableOpacity>

      {/* Centered Popup Modal */}
      <Modal
        visible={isMenuOpen}
        transparent
        animationType="none"
        onRequestClose={() => setIsMenuOpen(false)}
      >
        <View style={styles.modalContainer}>
          {/* Backdrop */}
          <TouchableOpacity
            style={styles.backdrop}
            activeOpacity={1}
            onPress={handleBackdropPress}
          >
            <Animated.View
              style={[
                styles.backdropAnimated,
                {
                  opacity: backdropOpacity,
                },
              ]}
            />
          </TouchableOpacity>

          {/* Centered Menu Popup */}
          <Animated.View
            style={[
              styles.popupContainer,
              {
                opacity: menuOpacity,
                transform: [{ scale: menuScale }],
              },
            ]}
          >
            <View style={styles.menu}>
              <TouchableOpacity
                style={styles.menuItem}
                onPress={() => handleOptionPress(onTakePhoto)}
              >
                <View style={styles.menuIconContainer}>
                  <Ionicons name="camera-outline" size={22} color={Colors.primary} />
                </View>
                <Text style={styles.menuItemText}>Take Photo</Text>
              </TouchableOpacity>

              <View style={styles.menuDivider} />

              <TouchableOpacity
                style={styles.menuItem}
                onPress={() => handleOptionPress(onPickImage)}
              >
                <View style={styles.menuIconContainer}>
                  <Ionicons name="image-outline" size={22} color={Colors.primary} />
                </View>
                <Text style={styles.menuItemText}>Choose from Library</Text>
              </TouchableOpacity>

              <View style={styles.menuDivider} />

              <TouchableOpacity
                style={styles.menuItem}
                onPress={() => handleOptionPress(onPickDocument)}
              >
                <View style={styles.menuIconContainer}>
                  <Ionicons name="document-outline" size={22} color={Colors.primary} />
                </View>
                <Text style={styles.menuItemText}>Choose File</Text>
              </TouchableOpacity>
            </View>
          </Animated.View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -Spacing.md,
  },
  uploadButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: 'transparent',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    minWidth: 160,
  },
  uploadButtonSuccess: {
    backgroundColor: 'transparent',
  },
  uploadButtonText: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.medium,
    color: Colors.white,
  },
  uploadButtonTextSuccess: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.medium,
    color: Colors.primary,
  },
  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backdropAnimated: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  popupContainer: {
    width: SCREEN_WIDTH - 80,
    maxWidth: 400,
  },
  menu: {
    backgroundColor: '#040404',
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.dark.border,
    paddingVertical: Spacing.xs,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
  },
  menuIconContainer: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(176, 19, 40, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  menuItemText: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.medium,
    color: Colors.white,
    flex: 1,
  },
  menuDivider: {
    height: 1,
    backgroundColor: Colors.dark.border,
    marginHorizontal: Spacing.lg,
  },
});
