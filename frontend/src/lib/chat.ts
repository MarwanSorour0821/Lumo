/**
 * Chat API functions for communicating with the Django backend
 */

// API base URL - adjust based on your environment
const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8000';

export type MessageType = 'text' | 'image' | 'pdf';

export interface ChatMessage {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  message_type: MessageType;
  file_name?: string | null;
  file_size?: number | null;
  created_at: string;
}

export interface SendMessageResponse {
  success: boolean;
  response?: string;
  error?: string;
}

export interface SendFileResponse {
  success: boolean;
  response?: string;
  file_type?: 'image' | 'pdf';
  file_name?: string;
  error?: string;
}

export interface GetHistoryResponse {
  success: boolean;
  messages?: ChatMessage[];
  error?: string;
}

export interface ClearHistoryResponse {
  success: boolean;
  deleted_count?: number;
  error?: string;
}

/**
 * Send a text message to the chat AI and get a response
 */
export async function sendChatMessage(
  userId: string,
  message: string
): Promise<SendMessageResponse> {
  try {
    const response = await fetch(`${API_BASE_URL}/api/chat/send/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user_id: userId,
        message: message,
      }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      return {
        success: false,
        error: data.error || 'Failed to send message',
      };
    }

    return {
      success: true,
      response: data.response,
    };
  } catch (error: any) {
    return {
      success: false,
      error: error.message || 'Network error',
    };
  }
}

/**
 * Send a file (image or PDF) to the chat AI and get a response
 */
export async function sendChatFile(
  userId: string,
  fileUri: string,
  fileName: string,
  mimeType: string,
  message?: string
): Promise<SendFileResponse> {
  try {
    // Create form data
    const formData = new FormData();
    formData.append('user_id', userId);
    
    if (message) {
      formData.append('message', message);
    }
    
    // Append file
    // React Native requires this specific format for file uploads
    formData.append('file', {
      uri: fileUri,
      name: fileName,
      type: mimeType,
    } as any);

    const response = await fetch(`${API_BASE_URL}/api/chat/send-file/`, {
      method: 'POST',
      body: formData,
      // Don't set Content-Type header - let fetch set it with boundary
    });

    const data = await response.json();
    
    if (!response.ok) {
      return {
        success: false,
        error: data.error || 'Failed to send file',
      };
    }

    return {
      success: true,
      response: data.response,
      file_type: data.file_type,
      file_name: data.file_name,
    };
  } catch (error: any) {
    return {
      success: false,
      error: error.message || 'Network error',
    };
  }
}

/**
 * Get chat history for a user
 */
export async function getChatHistory(
  userId: string,
  minutes: number = 30
): Promise<GetHistoryResponse> {
  try {
    const response = await fetch(`${API_BASE_URL}/api/chat/history/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user_id: userId,
        minutes: minutes,
      }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      return {
        success: false,
        error: data.error || 'Failed to get history',
      };
    }

    return {
      success: true,
      messages: data.messages,
    };
  } catch (error: any) {
    return {
      success: false,
      error: error.message || 'Network error',
    };
  }
}

/**
 * Clear chat history for a user
 */
export async function clearChatHistory(
  userId: string
): Promise<ClearHistoryResponse> {
  try {
    const response = await fetch(`${API_BASE_URL}/api/chat/clear/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user_id: userId,
      }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      return {
        success: false,
        error: data.error || 'Failed to clear history',
      };
    }

    return {
      success: true,
      deleted_count: data.deleted_count,
    };
  } catch (error: any) {
    return {
      success: false,
      error: error.message || 'Network error',
    };
  }
}





