import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { makeRedirectUri } from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { BiologicalSex } from '../types';

// Get Supabase credentials from environment variables
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

// Initialize Supabase client only if credentials are available
// If not available, the client will be null and functions will return appropriate errors
export const supabase: SupabaseClient | null =
  supabaseUrl && supabaseAnonKey
    ? createClient(supabaseUrl, supabaseAnonKey, {
        auth: {
          storage: AsyncStorage,
          autoRefreshToken: true,
          persistSession: true,
          detectSessionInUrl: false,
        },
      })
    : null;

export interface SignUpResponse {
  data: {
    user: {
      id: string;
      email?: string;
    } | null;
  };
  error: {
    message: string;
  } | null;
}

export interface ProfileResponse {
  error: {
    message: string;
  } | null;
}

export interface AppleSignInResponse {
  data: {
    user: {
      id: string;
      email?: string;
      firstName?: string;
      lastName?: string;
    } | null;
  };
  error: {
    message: string;
  } | null;
}

export interface SessionResponse {
  data: {
    user: {
      id: string;
      email?: string;
    } | null;
  };
  error: {
    message: string;
  } | null;
}

export interface SignInResponse {
  data: {
    user: {
      id: string;
      email?: string;
    } | null;
  };
  error: {
    message: string;
  } | null;
}

interface UpdateProfileParams {
  firstName?: string;
  lastName?: string;
  email?: string;
}

/**
 * Shared helper to perform an OAuth flow (Apple / Google) using expo-auth-session
 */
async function signInWithOAuthProvider(
  provider: 'apple' | 'google'
): Promise<AppleSignInResponse> {
  if (!supabase) {
    return {
      data: { user: null },
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    // For Expo Go / dev, use the Expo AuthSession proxy.
    // This will produce a redirect URL like:
    //   https://auth.expo.io/@your-username/Lumo/auth/callback
    // Make sure to add that exact URL to Supabase Auth -> Redirect URLs.
    // TS types for makeRedirectUri may not include `useProxy`, so cast options to any.
    const redirectUrl = makeRedirectUri({
      useProxy: true,
      path: 'auth/callback',
    } as any);
    console.log('Auth redirect URL (Supabase OAuth):', redirectUrl);

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: redirectUrl,
        // With the proxy we let the browser handle redirects normally.
        skipBrowserRedirect: false,
      },
    });

    if (error) {
      return {
        data: { user: null },
        error: { message: error.message },
      };
    }

    if (data?.url) {
      const result = await WebBrowser.openAuthSessionAsync(data.url, redirectUrl);

      if (result.type === 'success' && result.url) {
        const url = new URL(result.url);
        const params = new URLSearchParams(url.hash.substring(1));
        const accessToken = params.get('access_token');
        const refreshToken = params.get('refresh_token');

        if (accessToken) {
          const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken || '',
          });

          if (sessionError) {
            return {
              data: { user: null },
              error: { message: sessionError.message },
            };
          }

          if (sessionData.user) {
            const meta: any = (sessionData.user as any).user_metadata || {};
            const fullName: string | undefined =
              meta.full_name || meta.name || undefined;
            const inferredFirst =
              meta.given_name ||
              (fullName ? fullName.split(' ')[0] : undefined);
            const inferredLast =
              meta.family_name ||
              (fullName ? fullName.split(' ').slice(1).join(' ') || undefined : undefined);

            return {
              data: {
                user: {
                  id: sessionData.user.id,
                  email: sessionData.user.email || undefined,
                  firstName: inferredFirst,
                  lastName: inferredLast,
                },
              },
              error: null,
            };
          }
        }
      }

      if (result.type === 'cancel') {
        return {
          data: { user: null },
          error: { message: 'Sign in cancelled' },
        };
      }
    }

    return {
      data: { user: null },
      error: { message: `Failed to initiate ${provider} sign in` },
    };
  } catch (error: any) {
    return {
      data: { user: null },
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Sign in with Apple using Supabase OAuth */
export async function signInWithApple(): Promise<AppleSignInResponse> {
  return signInWithOAuthProvider('apple');
}

/** Sign in with Google using Supabase OAuth */
export async function signInWithGoogle(): Promise<AppleSignInResponse> {
  return signInWithOAuthProvider('google');
}

/** Sign in with email and password */
export async function signInWithEmail(
  email: string,
  password: string
): Promise<SignInResponse> {
  if (!supabase) {
    return {
      data: { user: null },
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return {
        data: { user: null },
        error: { message: error.message },
      };
    }

    return {
      data: {
        user: data.user ? { id: data.user.id, email: data.user.email || undefined } : null,
      },
      error: null,
    };
  } catch (error: any) {
    return {
      data: { user: null },
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Sign up a user with email and password */
export async function signUpWithEmail(
  email: string,
  password: string
): Promise<SignUpResponse> {
  if (!supabase) {
    return {
      data: { user: null },
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });

    if (data.user) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    return {
      data: {
        user: data.user ? { id: data.user.id, email: data.user.email || undefined } : null,
      },
      error: error ? { message: error.message } : null,
    };
  } catch (error: any) {
    return {
      data: { user: null },
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Create a user profile in the public.users table */
export async function createUserProfile(
  userId: string,
  biologicalSex: BiologicalSex,
  dateOfBirth: Date,
  heightCm: number,
  weightKg: number,
  firstName?: string,
  lastName?: string,
  email?: string
): Promise<ProfileResponse> {
  if (!supabase) {
    return {
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    await new Promise(resolve => setTimeout(resolve, 1000));

    const profileData: any = {
      id: userId,
      biological_sex: biologicalSex,
      date_of_birth: dateOfBirth.toISOString(),
      height_cm: heightCm,
      weight_kg: weightKg,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (firstName && firstName.trim()) profileData.first_name = firstName.trim();
    if (lastName && lastName.trim()) profileData.last_name = lastName.trim();
    if (email && email.trim()) profileData.email = email.trim();

    const { error } = await supabase.from('users').upsert(profileData, { onConflict: 'id' });

    if (error) {
      return { error: { message: error.message } };
    }

    return { error: null };
  } catch (error: any) {
    return {
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Get the current session/user */
export async function getCurrentSession(): Promise<SessionResponse> {
  if (!supabase) {
    return {
      data: { user: null },
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const {
      data: { session },
      error,
    } = await supabase.auth.getSession();

    if (error) {
      return {
        data: { user: null },
        error: { message: error.message },
      };
    }

    if (session?.user) {
      return {
        data: {
          user: {
            id: session.user.id,
            email: session.user.email || undefined,
          },
        },
        error: null,
      };
    }

    return {
      data: { user: null },
      error: null,
    };
  } catch (error: any) {
    return {
      data: { user: null },
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Get the full user profile from the users table */
export async function getUserProfile(
  userId: string
): Promise<{
  data: {
    first_name?: string;
    last_name?: string;
    email?: string;
    biological_sex?: BiologicalSex;
    date_of_birth?: string;
    height_cm?: number;
    weight_kg?: number;
  } | null;
  error: { message: string } | null;
}> {
  if (!supabase) {
    return {
      data: null,
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const { data, error } = await supabase.from('users').select('*').eq('id', userId).single();

    if (error) {
      return {
        data: null,
        error: { message: error.message },
      };
    }

    const mapped = {
      first_name: data?.first_name || data?.firstName || undefined,
      last_name: data?.last_name || data?.lastName || undefined,
      email: data?.email || undefined,
      biological_sex: data?.biological_sex || data?.biologicalSex || undefined,
      date_of_birth: data?.date_of_birth || data?.dateOfBirth || undefined,
      height_cm: data?.height_cm || data?.heightCm || undefined,
      weight_kg: data?.weight_kg || data?.weightKg || undefined,
    };

    return { data: mapped, error: null };
  } catch (error: any) {
    return {
      data: null,
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Update user profile (public.users) and auth email if provided */
export async function updateUserProfile(
  userId: string,
  { firstName, lastName, email }: UpdateProfileParams
): Promise<{ error: { message: string } | null }> {
  if (!supabase) {
    return {
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const updatePayload: any = {
      updated_at: new Date().toISOString(),
    };

    if (firstName && firstName.trim()) updatePayload.first_name = firstName.trim();
    if (lastName && lastName.trim()) updatePayload.last_name = lastName.trim();
    if (email && email.trim()) updatePayload.email = email.trim();

    const { error: profileError } = await supabase
      .from('users')
      .update(updatePayload)
      .eq('id', userId);

    if (profileError) {
      return { error: { message: profileError.message } };
    }

    if (email && email.trim()) {
      const { error: authError } = await supabase.auth.updateUser({
        email: email.trim(),
      });
      if (authError) {
        return { error: { message: authError.message } };
      }
    }

    return { error: null };
  } catch (error: any) {
    return {
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Update user password (requires active session) */
export async function updateUserPassword(
  newPassword: string
): Promise<{ error: { message: string } | null }> {
  if (!supabase) {
    return {
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) {
      return { error: { message: error.message } };
    }
    return { error: null };
  } catch (error: any) {
    return {
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}

/** Get the user's account creation date from the users table */
export async function getUserCreationDate(
  userId: string
): Promise<{ data: Date | null; error: { message: string } | null }> {
  if (!supabase) {
    return {
      data: null,
      error: {
        message:
          'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY environment variables.',
      },
    };
  }

  try {
    const { data, error } = await supabase
      .from('users')
      .select('created_at')
      .eq('id', userId)
      .single();

    if (error) {
      return {
        data: null,
        error: { message: error.message },
      };
    }

    if (data?.created_at) {
      return {
        data: new Date(data.created_at),
        error: null,
      };
    }

    return {
      data: null,
      error: null,
    };
  } catch (error: any) {
    return {
      data: null,
      error: { message: error?.message || 'An unexpected error occurred' },
    };
  }
}
