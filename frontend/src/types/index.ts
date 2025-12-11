export type BiologicalSex = 'male' | 'female';

export interface SignUpData {
  firstName: string;
  lastName: string;
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

export type RootStackParamList = {
  Welcome: undefined;
  SignUpPersonal: undefined;
  SignUpBiometrics: { signUpData: SignUpData };
  MainApp: undefined;
  AnalysisResults: { analysisData: BloodTestAnalysisResponse };
};

export type TabParamList = {
  Home: undefined;
  Analyse: undefined;
  History: undefined;
};

