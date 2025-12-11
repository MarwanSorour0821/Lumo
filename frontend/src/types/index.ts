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

// For Apple Sign In, we store the user info differently
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
  SignUpPersonal: undefined;
  SignUpCredentials: { firstName: string; lastName: string };
  SignUpSex: { signUpData: SignUpData | AppleSignUpData };
  SignUpAge: { signUpData: SignUpData | AppleSignUpData; sex: BiologicalSex };
  SignUpHeight: { signUpData: SignUpData | AppleSignUpData; sex: BiologicalSex; age: string };
  SignUpWeight: { 
    signUpData: SignUpData | AppleSignUpData; 
    sex: BiologicalSex; 
    age: string; 
    height: string; 
    heightFeet: string; 
    heightInches: string; 
    heightUnit: 'cm' | 'ft' 
  };
  Home: undefined;
  MyLab: undefined;
  Chat: undefined;
  Settings: undefined;
  NotificationSettings: undefined;
  EditInformation: undefined;
};

