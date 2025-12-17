/**
 * API types and functions for blood test analysis
 */

import { supabase } from './supabase';

// API base URL - adjust based on your environment
const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8000';

export interface PatientInfo {
  name?: string | null;
  age?: string | null;
  test_date?: string | null;
}

export interface TestResult {
  marker: string;
  value: string;
  unit: string;
  reference_range: string;
  status: 'normal' | 'high' | 'low' | null;
}

export interface ParsedBloodTestData {
  patient_info: PatientInfo;
  test_results: TestResult[];
}

export interface BloodTestAnalysisResponse {
  parsed_data: ParsedBloodTestData;
  analysis: string;
  structured_analysis?: any;
  created_at: string;
}

export interface AnalysisListItem {
  id: string;
  title: string;
  markers_count: number;
  summary: string;
  created_at: string;
}

export interface AnalysisDetail extends BloodTestAnalysisResponse {
  id: string;
  user_id: string;
  title?: string | null;
  updated_at: string;
}

/**
 * Get authentication headers with Supabase token
 */
async function getAuthHeaders(): Promise<HeadersInit> {
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
  };

  if (supabase) {
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.access_token) {
      headers['Authorization'] = `Bearer ${session.access_token}`;
    }
  }

  return headers;
}

/**
 * Get all analyses for the authenticated user
 */
export async function getAnalyses(): Promise<AnalysisListItem[]> {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/analyses/`, {
      method: 'GET',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Failed to fetch analyses: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error: any) {
    throw new Error(error.message || 'Failed to fetch analyses');
  }
}

/**
 * Get a single analysis by ID
 */
export async function getAnalysis(analysisId: string): Promise<AnalysisDetail> {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/analyses/${analysisId}/`, {
      method: 'GET',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Failed to fetch analysis: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error: any) {
    throw new Error(error.message || 'Failed to fetch analysis');
  }
}

/**
 * Analyze a blood test file (image or PDF)
 * @param fileUri - Local file URI from image picker or document picker
 * @returns Analysis result with parsed data and analysis text
 */
export async function analyzeBloodTest(fileUri: string): Promise<BloodTestAnalysisResponse> {
  try {
    // Get auth token for the request
    let authToken = '';
    if (supabase) {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        authToken = session.access_token;
      }
    }

    // Create FormData for file upload
    const formData = new FormData();
    
    // Get file name from URI (fallback to a default name)
    const fileName = fileUri.split('/').pop() || 'blood_test.jpg';
    const fileType = fileName.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
    
    // Append file to FormData
    // @ts-ignore - React Native FormData typing
    formData.append('file', {
      uri: fileUri,
      type: fileType,
      name: fileName,
    } as any);

    // Make request with FormData (don't set Content-Type, let fetch set it with boundary)
    const headers: HeadersInit = {};
    if (authToken) {
      headers['Authorization'] = `Bearer ${authToken}`;
    }

    const response = await fetch(`${API_BASE_URL}/api/ai/analyze/`, {
      method: 'POST',
      headers,
      body: formData,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Failed to analyze blood test: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error: any) {
    throw new Error(error.message || 'Failed to analyze blood test');
  }
}

/**
 * Save an analysis to the database
 * @param parsedData - Parsed blood test data
 * @param structuredAnalysis - Structured analysis data (JSON object)
 * @returns Saved analysis with ID
 */
export async function saveAnalysis(
  parsedData: ParsedBloodTestData,
  structuredAnalysis?: any
): Promise<AnalysisDetail> {
  try {
    const headers = await getAuthHeaders();
    
    // Prepare request body - analysis should be a JSON object, not a string
    const body: any = {
      parsed_data: parsedData,
      analysis: structuredAnalysis || {},
    };

    const response = await fetch(`${API_BASE_URL}/api/analyses/`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Failed to save analysis: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error: any) {
    throw new Error(error.message || 'Failed to save analysis');
  }
}

/**
 * Delete all user account data (analyses, chat messages)
 * Note: This does NOT delete the Supabase auth user - that must be done separately
 */
export async function deleteAccountData(): Promise<{ message: string; analyses_deleted: number; chat_messages_deleted: number }> {
  try {
    const headers = await getAuthHeaders();
    const response = await fetch(`${API_BASE_URL}/api/analyses/delete-account/`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `Failed to delete account data: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error: any) {
    throw new Error(error.message || 'Failed to delete account data');
  }
}




