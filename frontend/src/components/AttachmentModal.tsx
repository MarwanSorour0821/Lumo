import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  TouchableOpacity,
} from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { Colors, Spacing, FontSize } from '../constants/theme';

// Image Icon
const ImageIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M21 19V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M9 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM21 15l-5-5L5 21"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// File/PDF Icon
const FileIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M14 2v6h6M16 13H8M16 17H8M10 9H8"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Camera Icon
const CameraIcon = ({ size = 24, color = '#FFFFFF' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

interface AttachmentModalProps {
  visible: boolean;
  onClose: () => void;
  onTakePhoto: () => void;
  onPickImage: () => void;
  onPickFile: () => void;
}

export default function AttachmentModal({
  visible,
  onClose,
  onTakePhoto,
  onPickImage,
  onPickFile,
}: AttachmentModalProps) {
  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="slide"
      onRequestClose={onClose}
    >
      <Pressable
        style={styles.modalOverlay}
        onPress={onClose}
      >
        <View style={styles.modalContent}>
          <Pressable onPress={(e) => e.stopPropagation()}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add Attachment</Text>
            </View>
            <View style={styles.modalOptions}>
              <TouchableOpacity
                style={styles.modalOption}
                onPress={onTakePhoto}
                activeOpacity={0.7}
              >
                <View style={styles.modalOptionIcon}>
                  <CameraIcon size={32} color={Colors.white} />
                </View>
                <Text style={styles.modalOptionText}>Camera</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.modalOption}
                onPress={onPickImage}
                activeOpacity={0.7}
              >
                <View style={styles.modalOptionIcon}>
                  <ImageIcon size={32} color={Colors.white} />
                </View>
                <Text style={styles.modalOptionText}>Photo</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.modalOption}
                onPress={onPickFile}
                activeOpacity={0.7}
              >
                <View style={styles.modalOptionIcon}>
                  <FileIcon size={32} color={Colors.white} />
                </View>
                <Text style={styles.modalOptionText}>File</Text>
              </TouchableOpacity>
            </View>
          </Pressable>
        </View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: Colors.dark.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.xl,
  },
  modalHeader: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.dark.border,
  },
  modalTitle: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  modalOptions: {
    flexDirection: 'row',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    gap: Spacing.md,
  },
  modalOption: {
    flex: 1,
    alignItems: 'center',
    padding: Spacing.sm,
  },
  modalOptionIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: Colors.dark.background,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.sm,
  },
  modalOptionText: {
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
});

