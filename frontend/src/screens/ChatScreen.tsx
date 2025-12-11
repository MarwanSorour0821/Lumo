import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  StatusBar,
  ScrollView,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Modal,
  Pressable,
  Animated,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import Svg, { Path, Circle, G } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';
import { getCurrentSession, getUserProfile } from '../lib/supabase';

// Plus Icon (light gray)
const PlusIcon = ({ size = 20, color = '#808080' }: { size?: number; color?: string }) => (
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

// Microphone Icon
const MicrophoneIcon = ({ size = 20, color = '#808080' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <Path
      d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
    <Path
      d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8"
      stroke={color}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

// Send Icon
const SendIcon = ({ size = 20, color = '#000000' }: { size?: number; color?: string }) => (
  <Svg width={size} height={size} viewBox="0 0 48 48" fill="none">
    <Path
      d="M43 5L29.7 43l-7.6-17.1L5 18.3L43 5Z"
      stroke={color}
      strokeWidth={4}
      strokeLinejoin="round"
    />
    <Path
      d="M43 5L22.1 25.9"
      stroke={color}
      strokeWidth={4}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

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

// File Icon
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

type ChatScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Chat'>;
};

export function ChatScreen({ navigation }: ChatScreenProps) {
  const [message, setMessage] = useState('');
  const [modalVisible, setModalVisible] = useState(false);
  const [userName, setUserName] = useState<string | null>(null);
  const [isNameLoaded, setIsNameLoaded] = useState(false);
  const nameFade = useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    const fetchUserName = async () => {
      try {
        const { data: sessionData } = await getCurrentSession();
        console.log('ChatScreen - Session data:', sessionData);
        
        if (sessionData.user?.id) {
          // Get user profile from public.users table
          const { data: profileData, error } = await getUserProfile(sessionData.user.id);
          
          console.log('ChatScreen - Profile data:', profileData);
          console.log('ChatScreen - Profile error:', error);

          if (!error && profileData && profileData.first_name) {
            console.log('ChatScreen - Using first_name from profile:', profileData.first_name);
            setUserName(profileData.first_name);
          } else {
            // Try to get name from user metadata or email as last resort
            const emailName = sessionData.user.email?.split('@')[0];
            if (emailName) {
              // Capitalize first letter
              const capitalized = emailName.charAt(0).toUpperCase() + emailName.slice(1);
              console.log('ChatScreen - Using email name:', capitalized);
              setUserName(capitalized);
            } else {
              console.log('ChatScreen - No name found, leaving empty');
              setUserName(null);
            }
          }
        } else {
          console.log('ChatScreen - No user session');
          setUserName(null);
        }
      } catch (error) {
        console.error('Error fetching user name:', error);
        setUserName(null);
      }

      setIsNameLoaded(true);
    };

    fetchUserName();
  }, []);

  // Fade in the greeting smoothly when the name is ready
  React.useEffect(() => {
    if (isNameLoaded) {
      nameFade.setValue(0);
      Animated.timing(nameFade, {
        toValue: 1,
        duration: 450,
        useNativeDriver: true,
      }).start();
    }
  }, [isNameLoaded, nameFade]);

  const handlePickImage = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        alert('Sorry, we need camera roll permissions to select images!');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        quality: 1,
      });

      if (!result.canceled && result.assets[0]) {
        // Handle selected image
        console.log('Selected image:', result.assets[0].uri);
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error picking image:', error);
    }
  };

  const handlePickFile = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: '*/*',
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets[0]) {
        // Handle selected file
        console.log('Selected file:', result.assets[0]);
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error picking file:', error);
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        {/* Header with Back Button */}
        <View style={styles.header}>
          <BackButton
            onPress={() => navigation.goBack()}
            theme="dark"
          />
        </View>

        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}
        >
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.scrollContent}
            showsVerticalScrollIndicator={false}
          >
            {/* Centered Greeting */}
            <View style={styles.greetingContainer}>
              {isNameLoaded && (
                <Animated.View style={{ opacity: nameFade }}>
                  <Text style={styles.greetingText}>
                    Hello {userName ?? ''}
                  </Text>
                  <Text style={styles.greetingSubtext}>
                    How may I assist you?
                  </Text>
                </Animated.View>
              )}
            </View>
          </ScrollView>

          {/* Chat Input Bar */}
          <View style={styles.inputContainer}>
            {/* Left Plus Button */}
            <TouchableOpacity 
              style={styles.plusButton} 
              activeOpacity={0.7}
              onPress={() => setModalVisible(true)}
            >
              <PlusIcon size={20} color={Colors.dark.textSecondary} />
            </TouchableOpacity>

            {/* Text Input Field */}
            <View style={styles.inputWrapper}>
              <TextInput
                style={styles.textInput}
                placeholder="Ask anything"
                placeholderTextColor={Colors.dark.textSecondary}
                value={message}
                onChangeText={setMessage}
                multiline={false}
              />
              <TouchableOpacity style={styles.sendButton} activeOpacity={0.7}>
                <SendIcon size={20} color={Colors.black} />
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>

        {/* Attachment Modal */}
        <Modal
          visible={modalVisible}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setModalVisible(false)}
        >
          <Pressable
            style={styles.modalOverlay}
            onPress={() => setModalVisible(false)}
          >
            <View style={styles.modalContent}>
              <Pressable onPress={(e) => e.stopPropagation()}>
                <View style={styles.modalHeader}>
                  <Text style={styles.modalTitle}>Add Attachment</Text>
                </View>
                <View style={styles.modalOptions}>
                  <TouchableOpacity
                    style={styles.modalOption}
                    onPress={handlePickImage}
                    activeOpacity={0.7}
                  >
                    <View style={styles.modalOptionIcon}>
                      <ImageIcon size={32} color={Colors.white} />
                    </View>
                    <Text style={styles.modalOptionText}>Photo</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.modalOption}
                    onPress={handlePickFile}
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
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.dark.background,
  },
  safeArea: {
    flex: 1,
  },
  header: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.md,
    paddingBottom: Spacing.sm,
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xl,
  },
  greetingContainer: {
    alignItems: 'center',
  },
  greetingText: {
    fontSize: FontSize.xxxl,
    color: Colors.white,
    fontFamily: 'ProductSans-Bold',
    marginBottom: Spacing.sm,
    textAlign: 'center',
  },
  greetingSubtext: {
    fontSize: FontSize.lg,
    color: Colors.dark.textSecondary,
    fontFamily: 'ProductSans-Regular',
    textAlign: 'center',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.sm,
    gap: Spacing.sm,
  },
  plusButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.dark.surface,
    alignItems: 'center',
    justifyContent: 'center',
  },
  inputWrapper: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.dark.surface,
    borderRadius: BorderRadius.full,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    minHeight: 48,
  },
  textInput: {
    flex: 1,
    fontSize: FontSize.md,
    fontFamily: 'ProductSans-Regular',
    color: Colors.white,
    padding: 0,
    marginRight: Spacing.sm,
  },
  sendButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: Colors.white,
    alignItems: 'center',
    justifyContent: 'center',
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
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
  },
  modalOptions: {
    flexDirection: 'row',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    gap: Spacing.lg,
  },
  modalOption: {
    flex: 1,
    alignItems: 'center',
    padding: Spacing.md,
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

