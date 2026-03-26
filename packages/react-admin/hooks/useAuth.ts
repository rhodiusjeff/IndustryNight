'use client';

import { create } from 'zustand';
import { apiClient } from '@/lib/api/client';
import { clearSessionTokens, setSessionTokens } from '@/lib/auth/session';
import type { AdminUser } from '@/types/admin';

interface AuthState {
  admin: AdminUser | null;
  isLoading: boolean;
  isReady: boolean;
  error: string | null;
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
}

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  admin: AdminUser;
}

export const useAuth = create<AuthState>((set) => ({
  admin: null,
  isLoading: false,
  isReady: false,
  error: null,

  initialize: async () => {
    set({ isLoading: true, error: null });
    try {
      const response = await apiClient<{ admin: AdminUser }>('admin/auth/me');
      set({ admin: response.admin, isReady: true, isLoading: false });
    } catch {
      clearSessionTokens();
      set({ admin: null, isReady: true, isLoading: false });
    }
  },

  login: async (email: string, password: string) => {
    set({ isLoading: true, error: null });
    try {
      const response = await apiClient<AuthResponse>('admin/auth/login', {
        method: 'POST',
        body: { email, password },
        retryOnUnauthorized: false,
      });
      setSessionTokens(response.accessToken, response.refreshToken);
      set({ admin: response.admin, isLoading: false, isReady: true });
      return true;
    } catch {
      set({ error: 'Invalid email or password', isLoading: false, isReady: true });
      return false;
    }
  },

  logout: async () => {
    try {
      await apiClient<{ message: string }>('admin/auth/logout', {
        method: 'POST',
      });
    } catch {
      // Ignore network/logout failures and always clear local session.
    }
    clearSessionTokens();
    set({ admin: null, isReady: true, isLoading: false, error: null });
  },
}));
