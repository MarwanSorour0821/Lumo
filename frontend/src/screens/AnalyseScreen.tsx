import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert, Modal, Pressable, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import Svg, { Path, G } from 'react-native-svg';
import { Button } from '../components/Button';
import BloodCellsLoader from '../components/BloodCellsLoader';
import { SmoothUploadFlow } from '../components/SmoothUploadFlow';
import BackButton from '../../components/BackButton';
import { Colors, FontSize, FontWeight, Spacing, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import { analyzeBloodTest, saveAnalysis } from '../lib/api';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

export function AnalyseScreen() {
  const navigation = useNavigation<NavigationProp>();
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [fileType, setFileType] = useState<'image' | 'pdf' | null>(null);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState<number>(0);
  const [attachmentModalVisible, setAttachmentModalVisible] = useState(false);

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
      const result = await analyzeBloodTest(selectedFile);
      
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
      setFileType(null);
      setLoading(false);
      setProgress(0);
      
      // Step 3: Navigate to MyLab with the new analysis ID to auto-open it
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
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <BackButton
          onPress={() => navigation.goBack()}
          theme="dark"
        />
      </View>
      <View style={styles.content}>
        {/* Document Icon */}
        <View style={styles.iconContainer}>
          <View style={styles.iconWrapper}>
            <DocumentIcon />
          </View>
        </View>

        {/* Title */}
        <Text style={styles.title}>Upload a photo or PDF of your blood test</Text>

        {/* Subtitle */}
        <Text style={styles.subtitle}>
          Make sure all information is clear and visible for the most accurate results
        </Text>

        {/* Smooth Upload Flow */}
        <SmoothUploadFlow
          onTakePhoto={handleTakePhoto}
          onPickImage={handlePickImage}
          onPickDocument={handlePickDocument}
          selectedFile={selectedFile}
          fileType={fileType}
          onOpenModal={() => setAttachmentModalVisible(true)}
        />
      </View>
      
      {/* Attachment Modal - reuse chat screen bottom sheet style */}
      <Modal
        visible={attachmentModalVisible}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setAttachmentModalVisible(false)}
      >
        <Pressable
          style={styles.modalOverlay}
          onPress={() => setAttachmentModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <Pressable onPress={(e) => e.stopPropagation()}>
              <View style={styles.modalHeader}>
                <Text style={styles.modalTitle}>Add Attachment</Text>
              </View>
              <View style={styles.modalOptions}>
                <TouchableOpacity
                  style={styles.modalOption}
                  onPress={() => {
                    setAttachmentModalVisible(false);
                    handleTakePhoto();
                  }}
                  activeOpacity={0.7}
                >
                  <View style={styles.modalOptionIcon}>
                    <CameraIcon size={32} color={Colors.white} />
                  </View>
                  <Text style={styles.modalOptionText}>Camera</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.modalOption}
                  onPress={() => {
                    setAttachmentModalVisible(false);
                    handlePickImage();
                  }}
                  activeOpacity={0.7}
                >
                  <View style={styles.modalOptionIcon}>
                    <ImageIcon size={32} color={Colors.white} />
                  </View>
                  <Text style={styles.modalOptionText}>Photo</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.modalOption}
                  onPress={() => {
                    setAttachmentModalVisible(false);
                    handlePickDocument();
                  }}
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
      
      {/* Done Button or Loading Progress Bar */}
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
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.md,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
    marginTop: -Spacing.xxl * 2,
  },
  iconContainer: {
    marginBottom: Spacing.xxl,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    paddingRight: 30,
  },
  iconWrapper: {
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
  },
  title: {
    fontSize: FontSize.xl,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    textAlign: 'center',
    marginTop: -Spacing.xxl * 2,
    marginBottom: Spacing.md,
    lineHeight: FontSize.xl * 1.3,
  },
  subtitle: {
    fontSize: FontSize.sm,
    color: Colors.dark.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.lg,
    lineHeight: FontSize.sm * 1.5,
  },
  buttonContainer: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
    alignItems: 'center',
  },
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
    fontWeight: '600',
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
    color: Colors.white,
  },
});
