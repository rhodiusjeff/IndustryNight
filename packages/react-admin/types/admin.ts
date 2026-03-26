export type AdminRole = 'platformAdmin' | 'moderator' | 'eventOps';

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
}

export interface DashboardStats {
  totalUsers: number;
  activeEvents: number;
  connectionsMade: number;
  communityPosts: number;
}

export interface DashboardApiStats {
  total_users: number;
  upcoming_events: number;
  total_connections: number;
  total_posts: number;
}
