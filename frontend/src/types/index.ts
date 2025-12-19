export type BiologicalSex = 'male' | 'female' | 'other' | 'prefer_not_to_say';

export interface SignUpData {
  firstName: string;
  lastName?: string; // optional last name
  email: string;
  password: string;
}

export interface BiometricsData {
  biologicalSex: BiologicalSex;
  dateOfBirth: Date;
  heightCm: number;
  weightKg: number;
}

export interface UserProfile {
  id: string;
  biologicalSex: BiologicalSex;
  dateOfBirth: Date;
  heightCm: number;
  weightKg: number;
  createdAt: Date;
  updatedAt: Date;
}

import { BloodTestAnalysisResponse } from '../lib/api';

export interface AppleSignUpData {
  userId: string;
  email?: string;
  firstName?: string;
  lastName?: string;
  isAppleSignIn: true;
}

// Type for analysis data in route params - analysis can be string (from API) or JSON (from saved in future)
export interface AnalysisRouteData {
  parsed_data: BloodTestAnalysisResponse['parsed_data'];
  analysis: string | any; // keep flexible to allow structured JSON
  created_at: string;
}

export type RootStackParamList = {
  Onboarding: undefined;
  Login: undefined;
  SignUpPersonal: {
    signUpData: SignUpData | AppleSignUpData;
    sex: BiologicalSex;
    age: string;
    height: string;
    heightFeet: string;
    heightInches: string;
    heightUnit: 'cm' | 'ft';
    weight: string;
    weightUnit: 'kg' | 'lbs';
  };
  SignUpCredentials: { 
    signUpData: SignUpData | AppleSignUpData;
    sex: BiologicalSex;
    age: string;
    height: string;
    heightFeet: string;
    heightInches: string;
    heightUnit: 'cm' | 'ft';
    weight: string;
    weightUnit: 'kg' | 'lbs';
    firstName: string;
    lastName?: string;
  };
  SignUpSex: { signUpData: SignUpData | AppleSignUpData };
  SignUpAge: { signUpData: SignUpData | AppleSignUpData; sex: BiologicalSex };
  SignUpHeight: {
    signUpData: SignUpData | AppleSignUpData;
    sex: BiologicalSex;
    age: string;
  };
  SignUpWeight: {
    signUpData: SignUpData | AppleSignUpData;
    sex: BiologicalSex;
    age: string;
    height: string;
    heightFeet: string;
    heightInches: string;
    heightUnit: 'cm' | 'ft';
  };
  SignUpBiometrics: { signUpData: SignUpData };
  MainApp: undefined;
  AnalysisResults: { 
    analysisData: AnalysisRouteData;
    analysisId?: string;
  };
  Home: undefined;
  MyLab: { openAnalysisId?: string } | undefined;
  Chat: undefined;
  Settings: undefined;
  Analyse: undefined;
  NotificationSettings: undefined;
  EditInformation: undefined;
  PaywallLearnMore: undefined;
  PaywallMain: undefined;
  PaywallWelcome: undefined;
};

export type TabParamList = {
  Home: undefined;
  Analyse: undefined;
  History: undefined;
};