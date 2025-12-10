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

export type RootStackParamList = {
  Onboarding: undefined;
  SignUpPersonal: undefined;
  SignUpCredentials: { firstName: string; lastName: string };
  SignUpSex: { signUpData: SignUpData };
  SignUpAge: { signUpData: SignUpData; sex: BiologicalSex };
  SignUpHeight: { signUpData: SignUpData; sex: BiologicalSex; age: string };
  SignUpWeight: { 
    signUpData: SignUpData; 
    sex: BiologicalSex; 
    age: string; 
    height: string; 
    heightFeet: string; 
    heightInches: string; 
    heightUnit: 'cm' | 'ft' 
  };
  Home: undefined;
};

