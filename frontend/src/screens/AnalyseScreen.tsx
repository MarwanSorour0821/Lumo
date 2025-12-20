import React, { useState, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, Alert, Modal, Pressable, TouchableOpacity, Dimensions, Animated } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import Svg, { Path, G } from 'react-native-svg';
import { Button } from '../components/Button';
import BloodCellsLoader from '../components/BloodCellsLoader';
import BackButton from '../../components/BackButton';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { analyzeBloodTest, saveAnalysis } from '../lib/api';
import { usePaywall } from '../contexts/PaywallContext';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

interface AnalyseScreenProps {
  visible: boolean;
  onClose: () => void;
}

interface SelectedFile {
  uri: string;
  fileName: string;
  mimeType: string;
  type: 'image' | 'pdf';
}

export function AnalyseScreen({ visible, onClose }: AnalyseScreenProps) {
  const navigation = useNavigation<NavigationProp>();
  const { hasActiveSubscription } = usePaywall();
  const [selectedFile, setSelectedFile] = useState<SelectedFile | null>(null);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState<number>(0);
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(-20)).current;

  // Animate file preview when selectedFile changes
  useEffect(() => {
    if (selectedFile) {
      Animated.parallel([
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.spring(slideAnim, {
          toValue: 0,
          friction: 8,
          tension: 40,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      fadeAnim.setValue(0);
      slideAnim.setValue(-20);
    }
  }, [selectedFile, fadeAnim, slideAnim]);

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
      const asset = result.assets[0];
      const fileName = asset.fileName || `photo_${Date.now()}.jpg`;
      setSelectedFile({
        uri: asset.uri,
        fileName: fileName,
        mimeType: asset.mimeType || 'image/jpeg',
        type: 'image',
      });
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
      const asset = result.assets[0];
      const fileName = asset.fileName || `image_${Date.now()}.jpg`;
      setSelectedFile({
        uri: asset.uri,
        fileName: fileName,
        mimeType: asset.mimeType || 'image/jpeg',
        type: 'image',
      });
    }
  };

  const handlePickFile = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'image/*'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets[0]) {
        const asset = result.assets[0];
        const isPdf = asset.mimeType?.includes('pdf') || false;
        
        // Check subscription status for PDF uploads only
        if (isPdf && !hasActiveSubscription) {
          navigation.navigate('PaywallMain');
          return;
        }
        
        setSelectedFile({
          uri: asset.uri,
          fileName: asset.name,
          mimeType: asset.mimeType || (isPdf ? 'application/pdf' : 'image/jpeg'),
          type: isPdf ? 'pdf' : 'image',
        });
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

    // Check subscription status - block if user doesn't have subscription
    if (!hasActiveSubscription) {
      navigation.navigate('PaywallMain');
      return;
    }
    
    setLoading(true);
    setProgress(0);
    
    // Progress tracking: simulate Textract progress (0-50%) over 40-50 seconds
    // Then complete to 100% when API call finishes
    const progressInterval = setInterval(() => {
      setProgress(prev => {
        // Progress to 50% over ~45 seconds (Textract phase)
        if (prev < 50) {
          return Math.min(50, prev + 0.5);
        }
        // Once at 50%, slowly progress to 90% (GPT phase)
        else if (prev < 90) {
          return Math.min(90, prev + 0.2);
        }
        return prev;
      });
    }, 500); // Update every 500ms
    
    try {
      // Step 1: Analyze the blood test with AI
      // This includes Textract (~50% progress) and GPT-5.1 (~100% progress)
      const result = await analyzeBloodTest(selectedFile.uri);
      
      // Step 2: Save the analysis to the database
      const savedAnalysis = await saveAnalysis(
        result.parsed_data,
        result.structured_analysis
      );
      
      // Complete the progress
      clearInterval(progressInterval);
      setProgress(100);
      
      // Small delay to show 100% completion
      await new Promise(resolve => setTimeout(resolve, 300));
      
      // Reset the form
      setSelectedFile(null);
      setLoading(false);
      setProgress(0);
      
      // Close modal and navigate to MyLab with the new analysis ID to auto-open it
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

  const DocumentIcon = () => (
    <Svg width="258" height="300" viewBox="0 0 272 300" fill="none">
      <G>
        <Path d="M91.4286 34C85.7454 34 80.2949 36.2577 76.2763 40.2763C72.2576 44.2949 70 49.7454 70 55.4286V212.571C70 218.255 72.2576 223.705 76.2763 227.724C80.2949 231.742 85.7454 234 91.4286 234H220C225.683 234 231.134 231.742 235.152 227.724C239.171 223.705 241.429 218.255 241.429 212.571V98.2857C241.43 97.3471 241.247 96.4173 240.889 95.5496C240.531 94.6818 240.006 93.8931 239.343 93.2286L182.2 36.0857C181.535 35.4228 180.747 34.8974 179.879 34.5396C179.011 34.1817 178.081 33.9983 177.143 34H91.4286Z" fill="#B01328"/>
        <Path d="M146.614 105.386C145.875 105.38 145.143 105.521 144.459 105.801C143.775 106.082 143.154 106.495 142.632 107.017C142.109 107.54 141.696 108.161 141.416 108.845C141.136 109.528 140.994 110.261 141 111V133.286H118.714C117.978 133.282 117.248 133.424 116.567 133.704C115.886 133.984 115.267 134.397 114.746 134.917C114.225 135.438 113.813 136.057 113.533 136.738C113.253 137.419 113.111 138.149 113.114 138.886V157.1C113.114 160.2 115.614 162.7 118.714 162.7H141V184.986C141 188.086 143.514 190.6 146.6 190.6H164.829C165.565 190.604 166.295 190.461 166.976 190.181C167.657 189.901 168.276 189.489 168.797 188.968C169.318 188.447 169.73 187.829 170.01 187.147C170.29 186.466 170.432 185.736 170.429 185V162.714H192.714C193.452 162.718 194.183 162.575 194.865 162.294C195.547 162.013 196.167 161.6 196.688 161.077C197.209 160.555 197.621 159.935 197.9 159.252C198.179 158.569 198.32 157.838 198.314 157.1V138.886C198.318 138.149 198.176 137.419 197.896 136.738C197.616 136.057 197.203 135.438 196.683 134.917C196.162 134.397 195.543 133.984 194.862 133.704C194.181 133.424 193.451 133.282 192.714 133.286H170.429V111C170.434 110.262 170.293 109.531 170.014 108.848C169.735 108.165 169.323 107.545 168.802 107.022C168.281 106.5 167.662 106.087 166.979 105.806C166.297 105.525 165.566 105.382 164.829 105.386H146.614Z" fill="white"/>
      </G>
    </Svg>
  );

  // Video Camera Icon for Upload
  const VideoCameraIcon = ({ size = 48, color = Colors.primary }: { size?: number; color?: string }) => (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );

  // Camera Icon
  const CameraIcon = ({ size = 32, color = '#FFFFFF' }: { size?: number; color?: string }) => (
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

  // Image Icon
  const ImageIcon = ({ size = 32, color = '#FFFFFF' }: { size?: number; color?: string }) => (
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

  // File Icon
  const FileIcon = ({ size = 32, color = '#FFFFFF' }: { size?: number; color?: string }) => (
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

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="slide"
      onRequestClose={onClose}
    >
      <Pressable style={styles.modalOverlay} onPress={onClose}>
        <View style={styles.modalContent}>
          <Pressable onPress={(e) => e.stopPropagation()}>
            {/* Grab Handle */}
            <View style={styles.grabHandle} />
            
            {/* Header with Back Button */}
            <View style={styles.header}>
              <BackButton
                onPress={onClose}
                theme="dark"
              />
            </View>

            {/* Upload Section */}
            

            {/* Add Post Section - Attachment Options */}
            <View style={styles.addPostContainer}>
              {selectedFile ? (
                <Animated.View
                  style={[
                    styles.filePreviewContainer,
                    {
                      opacity: fadeAnim,
                      transform: [{ translateY: slideAnim }],
                    },
                  ]}
                >
                  <View style={styles.filePreview}>
                    {selectedFile.type === 'image' ? (
                      <ImageIcon size={20} color={Colors.primary} />
                    ) : (
                      <FileIcon size={20} color={Colors.primary} />
                    )}
                    <Text style={styles.filePreviewName} numberOfLines={1}>
                      {selectedFile.fileName}
                    </Text>
                    <TouchableOpacity
                      style={styles.removeFileButton}
                      onPress={() => setSelectedFile(null)}
                      activeOpacity={0.7}
                    >
                      <Text style={styles.removeFileText}>×</Text>
                    </TouchableOpacity>
                  </View>
                </Animated.View>
              ) : (
                <View style={styles.addPostBox}>
                  <Text style={styles.addPostText}>Add Post</Text>
                  <Text style={styles.addPostSubtext}>Export post to upload here</Text>
                  <View style={styles.attachmentOptions}>
                    <TouchableOpacity
                      style={styles.attachmentOption}
                      onPress={handleTakePhoto}
                      activeOpacity={0.7}
                    >
                      <View style={styles.attachmentOptionIcon}>
                        <CameraIcon size={32} color={Colors.white} />
                      </View>
                      <Text style={styles.attachmentOptionText}>Camera</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.attachmentOption}
                      onPress={handlePickImage}
                      activeOpacity={0.7}
                    >
                      <View style={styles.attachmentOptionIcon}>
                        <ImageIcon size={32} color={Colors.white} />
                      </View>
                      <Text style={styles.attachmentOptionText}>Photo</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.attachmentOption}
                      onPress={handlePickFile}
                      activeOpacity={0.7}
                    >
                      <View style={styles.attachmentOptionIcon}>
                        <FileIcon size={32} color={Colors.white} />
                      </View>
                      <Text style={styles.attachmentOptionText}>File</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              )}
            </View>

            {/* Continue Button or Loading Progress Bar */}
            <View style={styles.buttonContainer}>
              {loading ? (
                <BloodCellsLoader progress={progress} />
              ) : (
                <TouchableOpacity
                  style={[
                    styles.continueButton,
                    (!selectedFile || loading) && styles.continueButtonDisabled,
                  ]}
                  onPress={handleDone}
                  disabled={!selectedFile || loading}
                  activeOpacity={0.7}
                >
                  <Text style={[
                    styles.continueButtonText,
                    (!selectedFile || loading) && styles.continueButtonTextDisabled,
                  ]}>
                    Continue
                  </Text>
                  <Svg width={20} height={20} viewBox="0 0 24 24" fill="none">
                    <Path
                      d="M5 12h14M12 5l7 7-7 7"
                      stroke={(!selectedFile || loading) ? Colors.dark.textSecondary : Colors.white}
                      strokeWidth={2}
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </Svg>
                </TouchableOpacity>
              )}
            </View>
          </Pressable>
        </View>
      </Pressable>
    </Modal>
  );
}

const { width: SCREEN_WIDTH } = Dimensions.get('window');

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
    paddingTop: Spacing.sm,
    paddingBottom: Spacing.xl,
    maxHeight: '90%',
  },
  grabHandle: {
    width: 40,
    height: 4,
    backgroundColor: Colors.dark.border,
    borderRadius: 2,
    alignSelf: 'center',
    marginTop: Spacing.xs,
    marginBottom: Spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
  },
  uploadSection: {
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xl,
  },
  uploadTitle: {
    fontSize: FontSize.xxl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginTop: Spacing.md,
    marginBottom: Spacing.xs,
  },
  uploadSubtitle: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
  },
  addPostContainer: {
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.xl,
  },
  addPostBox: {
    borderWidth: 2,
    borderColor: Colors.dark.border,
    borderStyle: 'dashed',
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.dark.background,
    minHeight: 200,
  },
  addPostBoxFilled: {
    borderStyle: 'solid',
    borderColor: Colors.primary,
    backgroundColor: 'rgba(199, 0, 43, 0.1)',
  },
  addPostText: {
    fontSize: FontSize.lg,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    marginBottom: Spacing.xs,
  },
  addPostSubtext: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.lg,
  },
  attachmentOptions: {
    flexDirection: 'row',
    width: '100%',
    justifyContent: 'space-around',
    marginTop: Spacing.md,
    gap: Spacing.md,
  },
  attachmentOption: {
    flex: 1,
    alignItems: 'center',
    padding: Spacing.sm,
  },
  attachmentOptionIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: Colors.dark.surface,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.sm,
  },
  attachmentOptionText: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  filePreviewContainer: {
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.xl,
  },
  filePreview: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.black,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    gap: Spacing.sm,
  },
  filePreviewName: {
    flex: 1,
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
  },
  removeFileButton: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: Colors.dark.background,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeFileText: {
    fontSize: FontSize.lg,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    lineHeight: FontSize.lg,
  },
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
    alignItems: 'center',
  },
  continueButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.primary,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.full,
    gap: Spacing.sm,
    minWidth: SCREEN_WIDTH - Spacing.lg * 2,
  },
  continueButtonDisabled: {
    backgroundColor: Colors.dark.border,
  },
  continueButtonText: {
    fontSize: FontSize.md,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  },
  continueButtonTextDisabled: {
    color: Colors.dark.textSecondary,
  },
});
