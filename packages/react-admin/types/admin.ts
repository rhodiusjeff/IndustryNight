export interface DashboardStats {
  totalUsers: number
  activeEvents: number
  totalConnections: number
  totalPosts: number
}

export interface AdminUser {
  id: string
  email: string
  name: string
  role: 'platformAdmin' | 'moderator' | 'eventOps'
}

export interface LoginCredentials {
  email: string
  password: string
}

export interface AuthTokens {
  accessToken: string
  refreshToken: string
}

export interface LoginResponse {
  accessToken: string
  refreshToken: string
  admin: AdminUser
}

export interface ApiError {
  message: string
  status: number
}
