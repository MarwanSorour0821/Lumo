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
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import * as Haptics from 'expo-haptics';
import Svg, { Path } from 'react-native-svg';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { RootStackParamList } from '../types';
import BackButton from '../../components/BackButton';
import { getCurrentSession, getUserProfile } from '../lib/supabase';
import { sendChatMessage, getChatHistory, ChatMessage } from '../lib/chat';
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

// Message Bubble Component
const MessageBubble = ({ message }: { message: ChatMessage }) => {
  const isUser = message.role === 'user';
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(isUser ? 20 : -20)).current;

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
        {isUser ? (
          <Text style={styles.userMessageText}>{message.content}</Text>
        ) : (
          <MarkdownText style={styles.assistantMessageText}>
            {message.content}
          </MarkdownText>
        )}
      </View>
    </Animated.View>
  );
};

type ChatScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Chat'>;
};

export function ChatScreen({ navigation }: ChatScreenProps) {
  const [message, setMessage] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isTyping, setIsTyping] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [userName, setUserName] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [isInitialLoading, setIsInitialLoading] = useState(true);
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
    if (!message.trim() || !userId || isLoading) return;

    const userMessage = message.trim();
    setMessage('');
    
    // Haptic feedback
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    // Optimistically add user message
    const tempUserMessage: ChatMessage = {
      id: Date.now(),
      role: 'user',
      content: userMessage,
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
  }, [message, userId, isLoading]);

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
        console.log('Selected file:', result.assets[0]);
        setModalVisible(false);
      }
    } catch (error) {
      console.error('Error picking file:', error);
    }
  };

  const hasMessages = messages.length > 0;

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
                autoCorrect={false}
                autoCapitalize="none"
                autoComplete="off"
                textContentType="none"
                importantForAutofill="no"
                returnKeyType="send"
                onSubmitEditing={handleSendMessage}
                editable={!isLoading}
              />
              <TouchableOpacity 
                style={[
                  styles.sendButton,
                  (!message.trim() || isLoading) && styles.sendButtonDisabled,
                ]} 
                activeOpacity={0.7}
                onPress={handleSendMessage}
                disabled={!message.trim() || isLoading}
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
