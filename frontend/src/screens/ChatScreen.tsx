import React, { useRef, useState, useEffect, useCallback } from 'react';
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
  ActivityIndicator,
  Image,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import * as Haptics from 'expo-haptics';
import Svg, { Path } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';
import { getCurrentSession, getUserProfile } from '../lib/supabase';
import { sendChatMessage, sendChatFile, getChatHistory, ChatMessage } from '../lib/chat';
import { MarkdownText } from '../components/MarkdownText';

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

// Typing Indicator Component
const TypingIndicator = () => {
  const dot1 = useRef(new Animated.Value(0)).current;
  const dot2 = useRef(new Animated.Value(0)).current;
  const dot3 = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const animateDot = (dot: Animated.Value, delay: number) => {
      return Animated.loop(
        Animated.sequence([
          Animated.delay(delay),
          Animated.timing(dot, {
            toValue: 1,
            duration: 300,
            useNativeDriver: true,
          }),
          Animated.timing(dot, {
            toValue: 0,
            duration: 300,
            useNativeDriver: true,
          }),
        ])
      );
    };

    const animation = Animated.parallel([
      animateDot(dot1, 0),
      animateDot(dot2, 150),
      animateDot(dot3, 300),
    ]);

    animation.start();

    return () => animation.stop();
  }, [dot1, dot2, dot3]);

  const dotStyle = (animatedValue: Animated.Value) => ({
    opacity: animatedValue.interpolate({
      inputRange: [0, 1],
      outputRange: [0.3, 1],
    }),
    transform: [
      {
        translateY: animatedValue.interpolate({
          inputRange: [0, 1],
          outputRange: [0, -4],
        }),
      },
    ],
  });

  return (
    <View style={styles.typingContainer}>
      <View style={styles.typingBubble}>
        <Animated.View style={[styles.typingDot, dotStyle(dot1)]} />
        <Animated.View style={[styles.typingDot, dotStyle(dot2)]} />
        <Animated.View style={[styles.typingDot, dotStyle(dot3)]} />
      </View>
    </View>
  );
};

// File Attachment Display Component
const FileAttachment = ({ fileName, fileType, isUser }: { fileName: string; fileType: 'image' | 'pdf'; isUser: boolean }) => {
  const formatFileSize = (bytes?: number | null) => {
    if (!bytes) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <View style={[styles.fileAttachment, isUser ? styles.fileAttachmentUser : styles.fileAttachmentAssistant]}>
      <View style={styles.fileAttachmentIcon}>
        {fileType === 'image' ? (
          <ImageIcon size={20} color={isUser ? Colors.white : Colors.primary} />
        ) : (
          <FileIcon size={20} color={isUser ? Colors.white : Colors.primary} />
        )}
      </View>
      <View style={styles.fileAttachmentInfo}>
        <Text style={[styles.fileAttachmentName, isUser && styles.fileAttachmentNameUser]} numberOfLines={1}>
          {fileName}
        </Text>
        <Text style={[styles.fileAttachmentType, isUser && styles.fileAttachmentTypeUser]}>
          {fileType === 'image' ? 'Image' : 'PDF Document'}
        </Text>
      </View>
    </View>
  );
};

// Message Bubble Component
const MessageBubble = ({ message }: { message: ChatMessage }) => {
  const isUser = message.role === 'user';
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(isUser ? 20 : -20)).current;
  
  const isFileMessage = message.message_type === 'image' || message.message_type === 'pdf';

  useEffect(() => {
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
  }, [fadeAnim, slideAnim]);

  // Parse content to extract file info for user file messages
  const getDisplayContent = () => {
    if (isUser && isFileMessage && message.content) {
      // Remove the [Shared an image/PDF: filename] prefix from display
      const match = message.content.match(/^\[Shared (?:an image|a PDF): .+?\]\s*(.*)/);
      return match ? match[1] : message.content;
    }
    return message.content;
  };

  const displayContent = getDisplayContent();

  return (
    <Animated.View
      style={[
        styles.messageBubbleContainer,
        isUser ? styles.userBubbleContainer : styles.assistantBubbleContainer,
        {
          opacity: fadeAnim,
          transform: [{ translateX: slideAnim }],
        },
      ]}
    >
      <View
        style={[
          styles.messageBubble,
          isUser ? styles.userBubble : styles.assistantBubble,
        ]}
      >
        {/* Show file attachment indicator for file messages */}
        {isUser && isFileMessage && message.file_name && (
          <FileAttachment 
            fileName={message.file_name} 
            fileType={message.message_type as 'image' | 'pdf'} 
            isUser={isUser}
          />
        )}
        
        {/* Show message content */}
        {displayContent ? (
          isUser ? (
            <Text style={styles.userMessageText}>{displayContent}</Text>
          ) : (
            <MarkdownText style={styles.assistantMessageText}>
              {message.content}
            </MarkdownText>
          )
        ) : null}
      </View>
    </Animated.View>
  );
};

type ChatScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Chat'>;
};

interface SelectedFile {
  uri: string;
  fileName: string;
  mimeType: string;
  type: 'image' | 'pdf';
}

export function ChatScreen({ navigation }: ChatScreenProps) {
  const [message, setMessage] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isTyping, setIsTyping] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [userName, setUserName] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [isUploading, setIsUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<SelectedFile | null>(null);
  const nameFade = useRef(new Animated.Value(0)).current;
  const scrollViewRef = useRef<ScrollView>(null);

  // Load user info and chat history on mount
  useEffect(() => {
    const initialize = async () => {
      try {
        const { data: sessionData } = await getCurrentSession();
        
        if (sessionData.user?.id) {
          setUserId(sessionData.user.id);
          
          // Load user profile for name
          const { data: profileData, error } = await getUserProfile(sessionData.user.id);
          
          if (!error && profileData?.first_name) {
            setUserName(profileData.first_name);
          } else {
            const emailName = sessionData.user.email?.split('@')[0];
            if (emailName) {
              setUserName(emailName.charAt(0).toUpperCase() + emailName.slice(1));
            }
          }

          // Load chat history
          const historyResponse = await getChatHistory(sessionData.user.id);
          if (historyResponse.success && historyResponse.messages) {
            setMessages(historyResponse.messages);
          }
        }
      } catch (error) {
        console.error('Error initializing chat:', error);
      } finally {
        setIsInitialLoading(false);
      }
    };

    initialize();
  }, []);

  // Fade in greeting when loaded and no messages
  useEffect(() => {
    if (!isInitialLoading && messages.length === 0) {
      nameFade.setValue(0);
      Animated.timing(nameFade, {
        toValue: 1,
        duration: 450,
        useNativeDriver: true,
      }).start();
    }
  }, [isInitialLoading, messages.length, nameFade]);

  // Scroll to bottom when messages change
  useEffect(() => {
    if (messages.length > 0) {
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [messages, isTyping]);

  const handleSendMessage = useCallback(async () => {
    // Need either a message or a file to send
    if ((!message.trim() && !selectedFile) || !userId || isLoading || isUploading) return;

    const userMessage = message.trim();
    const fileToSend = selectedFile;
    
    // Clear input and file
    setMessage('');
    setSelectedFile(null);
    setModalVisible(false);
    
    // Haptic feedback
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    // If there's a file, send it with the message
    if (fileToSend) {
      // Optimistically add user file message
      const tempUserMessage: ChatMessage = {
        id: Date.now(),
        role: 'user',
        content: `[Shared ${fileToSend.type === 'image' ? 'an image' : 'a PDF'}: ${fileToSend.fileName}] ${userMessage}`,
        message_type: fileToSend.type,
        file_name: fileToSend.fileName,
        created_at: new Date().toISOString(),
      };
      setMessages(prev => [...prev, tempUserMessage]);
      
      // Show typing/uploading indicator
      setIsUploading(true);
      setIsTyping(true);

      try {
        const response = await sendChatFile(
          userId, 
          fileToSend.uri, 
          fileToSend.fileName, 
          fileToSend.mimeType,
          userMessage || undefined
        );
        
        if (response.success && response.response) {
          // Add assistant response
          const assistantMessage: ChatMessage = {
            id: Date.now() + 1,
            role: 'assistant',
            content: response.response,
            message_type: 'text',
            created_at: new Date().toISOString(),
          };
          setMessages(prev => [...prev, assistantMessage]);
          
          // Success haptic
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        } else {
          // Error - remove the optimistic message and show alert
          setMessages(prev => prev.filter(m => m.id !== tempUserMessage.id));
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
          Alert.alert('Upload Failed', response.error || 'Failed to upload file');
        }
      } catch (error: any) {
        console.error('Error sending file:', error);
        setMessages(prev => prev.filter(m => m.id !== tempUserMessage.id));
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        Alert.alert('Upload Failed', error.message || 'Failed to upload file');
      } finally {
        setIsUploading(false);
        setIsTyping(false);
      }
    } else {
      // Regular text message
      // Optimistically add user message
      const tempUserMessage: ChatMessage = {
        id: Date.now(),
        role: 'user',
        content: userMessage,
        message_type: 'text',
        created_at: new Date().toISOString(),
      };
      setMessages(prev => [...prev, tempUserMessage]);
      
      // Show typing indicator
      setIsLoading(true);
      setIsTyping(true);

      try {
        const response = await sendChatMessage(userId, userMessage);
        
        if (response.success && response.response) {
          // Add assistant response
          const assistantMessage: ChatMessage = {
            id: Date.now() + 1,
            role: 'assistant',
            content: response.response,
            message_type: 'text',
            created_at: new Date().toISOString(),
          };
          setMessages(prev => [...prev, assistantMessage]);
          
          // Success haptic
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        } else {
          // Error haptic
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
          console.error('Chat error:', response.error);
        }
      } catch (error) {
        console.error('Error sending message:', error);
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      } finally {
        setIsLoading(false);
        setIsTyping(false);
      }
    }
  }, [message, selectedFile, userId, isLoading, isUploading]);


  const handlePickImage = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Please grant photo library access to select images.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: false,
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        const asset = result.assets[0];
        const fileName = asset.fileName || `image_${Date.now()}.jpg`;
        const mimeType = asset.mimeType || 'image/jpeg';
        
        setSelectedFile({
          uri: asset.uri,
          fileName: fileName,
          mimeType: mimeType,
          type: 'image',
        });
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error picking image:', error);
      Alert.alert('Error', 'Failed to select image');
    }
  };

  const handleTakePhoto = async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Please grant camera access to take photos.');
        return;
      }

      const result = await ImagePicker.launchCameraAsync({
        allowsEditing: false,
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        const asset = result.assets[0];
        const fileName = `photo_${Date.now()}.jpg`;
        const mimeType = 'image/jpeg';
        
        setSelectedFile({
          uri: asset.uri,
          fileName: fileName,
          mimeType: mimeType,
          type: 'image',
        });
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error taking photo:', error);
      Alert.alert('Error', 'Failed to take photo');
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
        const isPdf = asset.mimeType === 'application/pdf';
        const fileType = isPdf ? 'pdf' : 'image';
        
        setSelectedFile({
          uri: asset.uri,
          fileName: asset.name,
          mimeType: asset.mimeType || (isPdf ? 'application/pdf' : 'image/jpeg'),
          type: fileType,
        });
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error picking file:', error);
      Alert.alert('Error', 'Failed to select file');
    }
  };

  const handleRemoveFile = () => {
    setSelectedFile(null);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const hasMessages = messages.length > 0;
  const isDisabled = isLoading || isUploading;

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        {/* Header with Gradient and Chat Title */}
        <LinearGradient
          colors={[Colors.black, Colors.transparent]}
          style={styles.headerGradient}
        >
          <View style={styles.header}>
            <BackButton
              onPress={() => navigation.goBack()}
              theme="dark"
            />
            <Text style={styles.headerTitle}>Chat</Text>
            <View style={styles.headerSpacer} />
          </View>
        </LinearGradient>

        <KeyboardAvoidingView
          style={styles.keyboardView}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}
        >
          <ScrollView
            ref={scrollViewRef}
            style={styles.scrollView}
            contentContainerStyle={[
              styles.scrollContent,
              !hasMessages && styles.scrollContentCentered,
            ]}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            {isInitialLoading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={Colors.primary} />
              </View>
            ) : !hasMessages ? (
              /* Centered Greeting - only shown when no messages */
              <View style={styles.greetingContainer}>
                <Animated.View style={{ opacity: nameFade }}>
                  <Text style={styles.greetingText}>
                    Hello {userName ?? ''}
                  </Text>
                  <Text style={styles.greetingSubtext}>
                    How may I assist you?
                  </Text>
                </Animated.View>
              </View>
            ) : (
              /* Chat Messages */
              <View style={styles.messagesContainer}>
                {messages.map((msg) => (
                  <MessageBubble key={msg.id} message={msg} />
                ))}
                {isTyping && <TypingIndicator />}
              </View>
            )}
          </ScrollView>

          {/* Selected File Preview */}
          {selectedFile && (
            <View style={styles.filePreviewContainer}>
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
                  onPress={handleRemoveFile}
                  activeOpacity={0.7}
                >
                  <Text style={styles.removeFileText}>×</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* Chat Input Bar */}
          <View style={styles.inputContainer}>
            {/* Left Plus Button */}
            <TouchableOpacity 
              style={[styles.plusButton, isDisabled && styles.buttonDisabled]} 
              activeOpacity={0.7}
              onPress={() => setModalVisible(true)}
              disabled={isDisabled}
            >
              {isUploading ? (
                <ActivityIndicator size="small" color={Colors.dark.textSecondary} />
              ) : (
                <PlusIcon size={20} color={Colors.dark.textSecondary} />
              )}
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
                autoCorrect={false}
                autoCapitalize="none"
                autoComplete="off"
                textContentType="none"
                importantForAutofill="no"
                returnKeyType="send"
                onSubmitEditing={handleSendMessage}
                editable={!isDisabled}
              />
              <TouchableOpacity 
                style={[
                  styles.sendButton,
                  (!message.trim() && !selectedFile || isDisabled) && styles.sendButtonDisabled,
                ]} 
                activeOpacity={0.7}
                onPress={handleSendMessage}
                disabled={(!message.trim() && !selectedFile) || isDisabled}
              >
                {isLoading ? (
                  <ActivityIndicator size="small" color={Colors.black} />
                ) : (
                  <SendIcon size={20} color={Colors.black} />
                )}
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
                    onPress={handleTakePhoto}
                    activeOpacity={0.7}
                  >
                    <View style={styles.modalOptionIcon}>
                      <CameraIcon size={32} color={Colors.white} />
                    </View>
                    <Text style={styles.modalOptionText}>Camera</Text>
                  </TouchableOpacity>
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
  headerGradient: {
    paddingTop: Spacing.md,
    paddingBottom: Spacing.lg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
  },
  headerTitle: {
    fontSize: FontSize.xl,
    fontFamily: 'ProductSans-Bold',
    color: Colors.white,
    flex: 1,
    textAlign: 'center',
  },
  headerSpacer: {
    width: 80, // Same width as BackButton to center the title
  },
  keyboardView: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
  },
  scrollContentCentered: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
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
  messagesContainer: {
    paddingTop: Spacing.md,
  },
  messageBubbleContainer: {
    marginBottom: Spacing.md,
  },
  userBubbleContainer: {
    alignItems: 'flex-end',
  },
  assistantBubbleContainer: {
    alignItems: 'flex-start',
  },
  messageBubble: {
    maxWidth: '85%',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm + 2,
    borderRadius: BorderRadius.lg,
  },
  userBubble: {
    backgroundColor: Colors.primary,
    borderBottomRightRadius: 4,
  },
  assistantBubble: {
    backgroundColor: Colors.dark.surface,
    borderBottomLeftRadius: 4,
  },
  userMessageText: {
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    lineHeight: FontSize.md * 1.4,
  },
  assistantMessageText: {
    fontSize: FontSize.md,
    color: Colors.white,
    fontFamily: 'ProductSans-Regular',
    lineHeight: FontSize.md * 1.4,
  },
  // File attachment styles
  fileAttachment: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.xs,
    paddingHorizontal: Spacing.sm,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.xs,
  },
  fileAttachmentUser: {
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
  },
  fileAttachmentAssistant: {
    backgroundColor: 'rgba(199, 0, 43, 0.1)',
  },
  fileAttachmentIcon: {
    marginRight: Spacing.sm,
  },
  fileAttachmentInfo: {
    flex: 1,
  },
  fileAttachmentName: {
    fontSize: FontSize.sm,
    fontFamily: 'ProductSans-Bold',
    color: Colors.primary,
  },
  fileAttachmentNameUser: {
    color: Colors.white,
  },
  fileAttachmentType: {
    fontSize: FontSize.xs,
    fontFamily: 'ProductSans-Regular',
    color: Colors.dark.textSecondary,
  },
  fileAttachmentTypeUser: {
    color: 'rgba(255, 255, 255, 0.7)',
  },
  typingContainer: {
    alignItems: 'flex-start',
    marginBottom: Spacing.md,
  },
  typingBubble: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.dark.surface,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm + 4,
    borderRadius: BorderRadius.lg,
    borderBottomLeftRadius: 4,
    gap: 4,
  },
  typingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.dark.textSecondary,
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
  buttonDisabled: {
    opacity: 0.5,
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
  sendButtonDisabled: {
    opacity: 0.5,
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
  filePreviewContainer: {
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.xs,
  },
  filePreview: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.dark.surface,
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
});
