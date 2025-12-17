import React, { useState, useEffect, useRef } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Platform,
  Dimensions,
  ScrollView,
  Keyboard,
  Animated,
  Alert,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, FontSize, Spacing, BorderRadius } from '../constants/theme';
import * as Haptics from 'expo-haptics';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import { analyzeBloodTest, saveAnalysis } from '../lib/api';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../types';
import BloodCellsLoader from './BloodCellsLoader';
import { Button } from './Button';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface CreateModalProps {
  visible: boolean;
  onClose: () => void;
}

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

export function CreateModal({ visible, onClose }: CreateModalProps) {
  const navigation = useNavigation<NavigationProp>();
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [fileType, setFileType] = useState<'image' | 'pdf' | null>(null);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState<number>(0);
  const [attachmentModalVisible, setAttachmentModalVisible] = useState(false);
  const heightAnim = useRef(new Animated.Value(SCREEN_HEIGHT * 0.65)).current;
  const backdropOpacity = useRef(new Animated.Value(0)).current;

  // Reset state when modal closes
  useEffect(() => {
    if (!visible) {
      setSelectedFile(null);
      setFileType(null);
      setLoading(false);
      setProgress(0);
    }
  }, [visible]);

  useEffect(() => {
    if (visible) {
      Animated.timing(backdropOpacity, {
        toValue: 1,
        duration: 500,
        easing: (t) => t * (2 - t),
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(backdropOpacity, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  }, [visible, backdropOpacity]);

  useEffect(() => {
    const keyboardWillShow = Keyboard.addListener(
      Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow',
      (e) => {
        const newHeight = Math.min(
          SCREEN_HEIGHT * 0.65 + e.endCoordinates.height,
          SCREEN_HEIGHT * 0.9
        );
        Animated.timing(heightAnim, {
          toValue: newHeight,
          duration: Platform.OS === 'ios' ? 250 : 200,
          useNativeDriver: false,
        }).start();
      }
    );
    const keyboardWillHide = Keyboard.addListener(
      Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide',
      () => {
        Animated.timing(heightAnim, {
          toValue: SCREEN_HEIGHT * 0.65,
          duration: Platform.OS === 'ios' ? 250 : 200,
          useNativeDriver: false,
        }).start();
      }
    );

    return () => {
      keyboardWillShow.remove();
      keyboardWillHide.remove();
    };
  }, [heightAnim]);

  const handleClose = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onClose();
  };

  const requestPermissions = async () => {
    const cameraPermission = await ImagePicker.requestCameraPermissionsAsync();
    const mediaLibraryPermission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    
    if (!cameraPermission.granted || !mediaLibraryPermission.granted) {
      Alert.alert(
        'Permissions Required',
        'Please grant camera and photo library permissions to upload your blood test.'
      );
      return false;
    }
    return true;
  };

  const handleTakePhoto = async () => {
    const hasPermission = await requestPermissions();
    if (!hasPermission) return;

    const result = await ImagePicker.launchCameraAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 1,
    });

    if (!result.canceled && result.assets[0]) {
      setSelectedFile(result.assets[0].uri);
      setFileType('image');
    }
  };

  const handlePickImage = async () => {
    const hasPermission = await requestPermissions();
    if (!hasPermission) return;

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 1,
    });

    if (!result.canceled && result.assets[0]) {
      setSelectedFile(result.assets[0].uri);
      setFileType('image');
    }
  };

  const handlePickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'image/*'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets[0]) {
        setSelectedFile(result.assets[0].uri);
        setFileType(result.assets[0].mimeType?.includes('pdf') ? 'pdf' : 'image');
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to pick document');
    }
  };


  const handleDone = async () => {
    if (!selectedFile) {
      Alert.alert('No File Selected', 'Please upload a photo or PDF of your blood test first.');
      return;
    }
    
    setLoading(true);
    setProgress(0);
    
    const progressInterval = setInterval(() => {
      setProgress(prev => {
        if (prev < 50) {
          return Math.min(50, prev + 0.5);
        } else if (prev < 90) {
          return Math.min(90, prev + 0.2);
        }
        return prev;
      });
    }, 500);
    
    try {
      const result = await analyzeBloodTest(selectedFile);
      const savedAnalysis = await saveAnalysis(
        result.parsed_data,
        result.structured_analysis
      );
      
      clearInterval(progressInterval);
      setProgress(100);
      await new Promise(resolve => setTimeout(resolve, 300));
      
      setSelectedFile(null);
      setFileType(null);
      setLoading(false);
      setProgress(0);
      
      onClose();
      navigation.navigate('MyLab', { openAnalysisId: savedAnalysis.id });
      
    } catch (error) {
      clearInterval(progressInterval);
      setLoading(false);
      setProgress(0);
      Alert.alert(
        'Analysis Failed',
        error instanceof Error ? error.message : 'Failed to analyze blood test. Please try again.'
      );
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={handleClose}
    >
      <View style={styles.container}>
        <Animated.View
          style={[
            styles.backdrop,
            { opacity: backdropOpacity }
          ]}
        >
          <TouchableOpacity
            style={StyleSheet.absoluteFill}
            activeOpacity={1}
            onPress={handleClose}
          />
        </Animated.View>

        <Animated.View style={[
          styles.modalContent,
          { height: heightAnim }
        ]}>
          {/* Drag Handle */}
          <View style={styles.dragHandle} />

          {/* Close Button */}
          <TouchableOpacity
            style={styles.closeButton}
            onPress={handleClose}
            activeOpacity={0.7}
          >
            <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
              <Path
                d="M18 6L6 18M6 6l12 12"
                stroke="#FFFFFF"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </Svg>
          </TouchableOpacity>

          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.scrollContent}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            {/* Document Icon */}
            <View style={styles.iconContainer}>
              <Svg width={30} height={30} viewBox="0 0 24 24" fill="none">
                <G fill="#B01328">
                  <Path
                    fillRule="evenodd"
                    d="M14 22h-4c-3.771 0-5.657 0-6.828-1.172C2 19.657 2 17.771 2 14v-4c0-3.771 0-5.657 1.172-6.828C4.343 2 6.239 2 10.03 2c.606 0 1.091 0 1.5.017c-.013.08-.02.161-.02.244l-.01 2.834c0 1.097 0 2.067.105 2.848c.114.847.375 1.694 1.067 2.386c.69.69 1.538.952 2.385 1.066c.781.105 1.751.105 2.848.105h4.052c.043.534.043 1.19.043 2.063V14c0 3.771 0 5.657-1.172 6.828C19.657 22 17.771 22 14 22Z"
                    clipRule="evenodd"
                  />
                  <Path d="m19.352 7.617l-3.96-3.563c-1.127-1.015-1.69-1.523-2.383-1.788L13 5c0 2.357 0 3.536.732 4.268C14.464 10 15.643 10 18 10h3.58c-.362-.704-1.012-1.288-2.228-2.383Z"/>
                </G>
              </Svg>
            </View>

            {/* Title */}
            <Text style={styles.title}>Upload</Text>

            {/* Subtitle */}
            <Text style={styles.subtitle}>Upload your blood test results to get analysis.</Text>

            {/* Upload Field */}
            <TouchableOpacity
              style={styles.uploadField}
              onPress={() => setAttachmentModalVisible(true)}
              activeOpacity={0.7}
            >
              {selectedFile ? (
                <View style={styles.uploadFieldContent}>
                  <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
                    <Path
                      d="M9 12l2 2 4-4M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9 9 4.03 9 9z"
                      stroke="#B01328"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </Svg>
                  <Text style={styles.uploadFieldTextSelected}>
                    {fileType === 'pdf' ? 'PDF' : 'Image'} Selected
                  </Text>
                </View>
              ) : (
                <View style={styles.uploadFieldContent}>
                  <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
                    <Path
                      d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"
                      stroke="#808080"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </Svg>
                  <Text style={styles.uploadFieldText}>Tap to upload</Text>
                </View>
              )}
            </TouchableOpacity>

            {/* Loading or Analyze Button */}
            {selectedFile && (
              <View style={styles.buttonContainer}>
                {loading ? (
                  <BloodCellsLoader progress={progress} />
                ) : (
                  <Button
                    title="Analyze"
                    onPress={handleDone}
                    variant="primary"
                    disabled={!selectedFile}
                    showArrow={false}
                  />
                )}
              </View>
            )}
          </ScrollView>
        </Animated.View>

        {/* Attachment Modal */}
        <Modal
          visible={attachmentModalVisible}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setAttachmentModalVisible(false)}
        >
          <TouchableOpacity
            style={styles.attachmentModalOverlay}
            activeOpacity={1}
            onPress={() => setAttachmentModalVisible(false)}
          >
            <View style={styles.attachmentModalContent}>
              <TouchableOpacity activeOpacity={1} onPress={(e) => e.stopPropagation()}>
                <View style={styles.attachmentModalHeader}>
                  <Text style={styles.attachmentModalTitle}>Add Attachment</Text>
                </View>
                <View style={styles.attachmentModalOptions}>
                  <TouchableOpacity
                    style={styles.attachmentModalOption}
                    onPress={() => {
                      setAttachmentModalVisible(false);
                      handleTakePhoto();
                    }}
                    activeOpacity={0.7}
                  >
                    <View style={styles.attachmentModalOptionIcon}>
                      <Svg width={32} height={32} viewBox="0 0 24 24" fill="none">
                        <Path
                          d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                        <Path
                          d="M12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </Svg>
                    </View>
                    <Text style={styles.attachmentModalOptionText}>Camera</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.attachmentModalOption}
                    onPress={() => {
                      setAttachmentModalVisible(false);
                      handlePickImage();
                    }}
                    activeOpacity={0.7}
                  >
                    <View style={styles.attachmentModalOptionIcon}>
                      <Svg width={32} height={32} viewBox="0 0 24 24" fill="none">
                        <Path
                          d="M21 19V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2z"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                        <Path
                          d="M9 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM21 15l-5-5L5 21"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </Svg>
                    </View>
                    <Text style={styles.attachmentModalOptionText}>Photo</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.attachmentModalOption}
                    onPress={() => {
                      setAttachmentModalVisible(false);
                      handlePickDocument();
                    }}
                    activeOpacity={0.7}
                  >
                    <View style={styles.attachmentModalOptionIcon}>
                      <Svg width={32} height={32} viewBox="0 0 24 24" fill="none">
                        <Path
                          d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                        <Path
                          d="M14 2v6h6M16 13H8M16 17H8M10 9H8"
                          stroke="#FFFFFF"
                          strokeWidth="1.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </Svg>
                    </View>
                    <Text style={styles.attachmentModalOptionText}>File</Text>
                  </TouchableOpacity>
                </View>
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        </Modal>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: '#040404',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    width: '100%',
    paddingTop: 12,
    paddingBottom: Platform.OS === 'ios' ? 40 : 24,
    overflow: 'hidden',
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
  },
  dragHandle: {
    width: 40,
    height: 4,
    backgroundColor: '#666666',
    borderRadius: 2,
    alignSelf: 'center',
    marginBottom: 20,
  },
  closeButton: {
    position: 'absolute',
    top: 16,
    right: 16,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#1A1A1A',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  iconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 15,
    marginBottom: 18,
  },
  title: {
    fontSize: 28,
    fontFamily: 'ProductSans-Bold',
    fontWeight: '700',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    fontFamily: 'ProductSans-Regular',
    color: '#808080',
    textAlign: 'center',
    marginBottom: 32,
  },
  uploadField: {
    marginTop: 24,
    width: '100%',
    minHeight: 120,
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: '#666666',
    borderRadius: 12,
    backgroundColor: '#1A1A1A',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 24,
    paddingHorizontal: 16,
  },
  uploadFieldContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  uploadFieldText: {
    fontSize: 16,
    fontFamily: 'ProductSans-Regular',
    color: '#808080',
  },
  uploadFieldTextSelected: {
    fontSize: 16,
    fontFamily: 'ProductSans-Regular',
    color: '#B01328',
  },
  buttonContainer: {
    marginTop: 24,
    width: '100%',
  },
  attachmentModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  attachmentModalContent: {
    backgroundColor: '#1A1A1A',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.xl,
  },
  attachmentModalHeader: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: '#333333',
  },
  attachmentModalTitle: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: '#FFFFFF',
    fontFamily: 'ProductSans-Regular',
  },
  attachmentModalOptions: {
    flexDirection: 'row',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    gap: Spacing.md,
  },
  attachmentModalOption: {
    flex: 1,
    alignItems: 'center',
    padding: Spacing.sm,
  },
  attachmentModalOptionIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#040404',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.sm,
  },
  attachmentModalOptionText: {
    fontSize: FontSize.md,
    color: '#FFFFFF',
    fontFamily: 'ProductSans-Regular',
  },
});

