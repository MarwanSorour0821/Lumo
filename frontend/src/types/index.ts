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

/** Added from analysisPage branch **/
import { BloodTestAnalysisResponse } from '../lib/api';

/** From main branch - KEEP **/
export interface AppleSignUpData {
  userId: string;
  email?: string;
  firstName?: string;
  lastName?: string;
  isAppleSignIn: true;
}

export type RootStackParamList = {
  Onboarding: undefined;
  Login: undefined;

  /** MAIN branch signup flow (keep) **/
  SignUpPersonal: undefined;
  SignUpCredentials: { firstName: string; lastName: string };
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

  /** YOUR branch screens (analysis) **/
  SignUpBiometrics: { signUpData: SignUpData };
  MainApp: undefined;
  AnalysisResults: { analysisData: BloodTestAnalysisResponse };

  /** MAIN branch app pages **/
  Home: undefined;
  MyLab: undefined;
  Chat: undefined;
  Settings: undefined;
  NotificationSettings: undefined;
  EditInformation: undefined;
};

/** YOUR Tab navigator types (keep) **/
export type TabParamList = {
  Home: undefined;
  Analyse: undefined;
  History: undefined;
};
