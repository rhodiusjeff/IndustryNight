# [Track-B1] React Admin — Auth + RBAC + Permission-Gated Navigation

**Track:** B (React Admin)
**Sequence:** 2 of 4 in Track B
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4
**A/B Test:** No
**Estimated Effort:** Medium (2-3 days)
**Dependencies:** C0 (schema migrations), B0 (React scaffold) — B0 must be complete before starting B1

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — Admin auth API endpoints, admin roles, JWT token families
- `docs/codex/track-B/B0-scaffold-design-system.md` — B0 scaffold structure, permissions.ts skeleton, auth patterns
- B0 scaffold: `packages/react-admin/` with empty auth shell but no real token management or login logic
- Admin auth API (`packages/api/routes/admin-auth.ts`): `POST /login`, `POST /refresh`, `GET /me`, `POST /logout`
- Admin users table (`admin_users`): email/password authentication with role field (enum: `platformAdmin`, `moderator`, `eventOps`)
- Reference implementation: Flutter admin app at `packages/admin-app/lib/providers/admin_state.dart` for token refresh patterns

---

## Goal

Implement the complete authentication and role-based access control (RBAC) system for the React admin app. After B0 we have a scaffold with an empty login page and a design system. After B1: the login form submits to the real API and validates credentials, JWT tokens are stored and auto-refreshed, each admin role sees only their permitted nav items, protected routes block unauthorized access, and page reloads re-authenticate silently. Nothing else changes — B2+ adds the actual admin features.

---

## Acceptance Criteria

**Authentication & Token Management:**
- [ ] Login form at `/login` submits email + password to `POST /api/admin/auth/login` (proxied)
- [ ] On success: `accessToken` and `refreshToken` stored in memory (module-level variable); optional: httpOnly cookie fallback
- [ ] On failure (401): inline error message "Invalid email or password" shown; form NOT cleared (UX allows retry without re-typing)
- [ ] Access token injected in `Authorization: Bearer {token}` header on all authenticated requests
- [ ] Refresh token used to obtain new access token before expiry via `POST /api/admin/auth/refresh`
- [ ] Token refresh happens automatically: (a) on 401 response, retry once; (b) 60 seconds before expiry via setTimeout

**Session & Auth State:**
- [ ] `useAuth()` hook returns `{ admin: AdminUser | null, isLoading: boolean, login(email, password): Promise<void>, logout(): Promise<void>, error: string | null }`
- [ ] On app mount: attempt silent refresh via `GET /api/admin/auth/me` with current token. If 401, try `POST /api/admin/auth/refresh`. If both fail, clear tokens and set `admin = null`
- [ ] Page reload: user stays logged in if refresh token still valid (verified by subsequent `/me` call)
- [ ] Page reload after refresh token expiry: redirected to `/login` on first protected route navigation
- [ ] Logout: calls `POST /api/admin/auth/logout`, clears tokens, sets `admin = null`, redirects to `/login`

**RBAC & Permissions:**
- [ ] `lib/auth/permissions.ts` fully implements:
  - `AdminRole` type: `'platformAdmin' | 'moderator' | 'eventOps'`
  - `NAV_PERMISSIONS`: record mapping role to visible nav items
  - `ROLE_PERMISSIONS`: fine-grained read/write per resource
  - `canAccess(role, resource, action)`: boolean
  - `canNavigateTo(role, navItem)`: boolean
- [ ] Platform admin: sees all nav items and has full read/write on all resources
- [ ] Moderator: sees only Dashboard + Moderation; read-only on Dashboard; read/write on Moderation
- [ ] Event Ops: sees only Dashboard + Event Ops (wristband check-in screen); read-only on Dashboard; read/write on wristband issuance
- [ ] Unknown roles default to no access (DENY by default)

**Navigation & Route Protection:**
- [ ] Sidebar renders only nav items where `canNavigateTo(admin.role, item) === true`
- [ ] Attempt to navigate to restricted route (e.g., moderator goes to `/customers`): silently redirect to first permitted page (e.g., `/`)
- [ ] Unauthenticated user (no token): middleware or layout redirects to `/login`
- [ ] Authenticated user navigates to `/login`: redirected to `/` (dashboard)
- [ ] All protected routes are in the `(dashboard)` route group

**API Client Integration:**
- [ ] `lib/api/admin-api-client.ts` (or similar): base fetch wrapper with:
  - Automatic `Authorization: Bearer {token}` injection
  - On 401: attempt token refresh, retry request once
  - On refresh 401: clear tokens, redirect to login
  - All `/admin` endpoints go through this client
- [ ] Proxy pattern (B0 established) maintained: requests go through `app/api/[...path]/route.ts`

**Error Handling:**
- [ ] Login errors: display inline message (not alert/toast); specific text for 401 vs 5xx
- [ ] Token refresh errors: silent redirect to login (no confusing error states)
- [ ] API errors on protected routes: 403 shows "Access Denied" page; 5xx shows "Service unavailable"

**Dev Experience:**
- [ ] No changes to `scripts/run-react-admin.sh` needed (B0 already handles env)
- [ ] Tokens work with `npm run dev` and `npm run build && npm run start` equally
- [ ] Logout + back-button: stays on login (no cached auth state visible)

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | After logging in with valid email/password, I see all nav sections (Dashboard, Users, Events, Customers, etc.) | Full RBAC display |
| Moderator | After logging in, I only see Dashboard and Moderation in the sidebar — no Users, Events, Customers | Role-gated nav |
| Event Ops staff | After logging in, I see Dashboard and Event Ops (a wristband check-in screen); navigating to /users shows 403 and redirects to first permitted page | Role-gated nav + redirect |
| Any admin | If my session expires (refresh token expired) and I navigate to /, I'm redirected to /login | Auto-redirect on invalid token |
| Any admin | After logout, clicking the back button doesn't show the authenticated app state | Secure session cleanup |
| Developer | Running `npm run dev` in packages/react-admin starts the app, the login form works against the dev API, and I can test all three roles | Dev ergonomics |

---

## Technical Spec

### File & Directory Structure

```
packages/react-admin/
├── lib/
│   ├── auth/
│   │   ├── auth-client.ts              # Token storage + refresh logic
│   │   ├── auth-context.tsx            # React context + useAuth hook
│   │   └── permissions.ts              # RBAC maps (extends B0)
│   ├── api/
│   │   └── admin-api-client.ts         # Fetch wrapper with auth + retry
│   └── ...
├── components/
│   ├── layout/
│   │   ├── Sidebar.tsx                 # Updated to use canNavigateTo()
│   │   ├── Topbar.tsx                  # Shows admin name + logout
│   │   └── ...
│   └── ...
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx                # Fully implemented login form
│   ├── (dashboard)/
│   │   ├── layout.tsx                  # Auth guard + shell layout
│   │   └── ...
│   ├── api/
│   │   └── [...path]/route.ts          # Existing proxy (from B0)
│   └── ...
└── middleware.ts                       # Auth redirect (enhanced from B0)
```

### Auth Client (`lib/auth/auth-client.ts`)

Manages token storage (memory) and refresh logic. Can optionally use httpOnly cookies, but memory is safer (reduces XSS exfiltration risk).

```typescript
// lib/auth/auth-client.ts
let accessToken: string | null = null;
let refreshToken: string | null = null;
let tokenRefreshTimer: NodeJS.Timeout | null = null;

export function getAccessToken(): string | null {
  return accessToken;
}

export function setTokens(access: string, refresh: string): void {
  accessToken = access;
  refreshToken = refresh;
  scheduleTokenRefresh(extractExpiresIn(access)); // jwt_decode or manual parse
}

export function clearTokens(): void {
  accessToken = null;
  refreshToken = null;
  if (tokenRefreshTimer) clearTimeout(tokenRefreshTimer);
  tokenRefreshTimer = null;
}

export async function refreshAccessToken(): Promise<boolean> {
  if (!refreshToken) return false;
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    setTokens(data.accessToken, data.refreshToken);
    return true;
  } catch {
    return false;
  }
}

export function scheduleTokenRefresh(expiresIn: number): void {
  if (tokenRefreshTimer) clearTimeout(tokenRefreshTimer);
  // Refresh 60 seconds before expiry
  const delayMs = Math.max((expiresIn - 60) * 1000, 5000);
  tokenRefreshTimer = setTimeout(async () => {
    await refreshAccessToken();
  }, delayMs);
}

function extractExpiresIn(token: string): number {
  // Decode JWT payload (use jwt_decode or manual parse)
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return 900; // 15 min default
    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    return Math.floor(payload.exp - Date.now() / 1000);
  } catch {
    return 900;
  }
}
```

### Auth Context (`lib/auth/auth-context.tsx`)

Provides the `useAuth()` hook and handles auth state at app level.

```typescript
// lib/auth/auth-context.tsx
'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { AdminUser } from '@/types/admin';
import {
  getAccessToken,
  setTokens,
  clearTokens,
  refreshAccessToken,
} from './auth-client';

interface AuthContextValue {
  admin: AdminUser | null;
  isLoading: boolean;
  error: string | null;
  login(email: string, password: string): Promise<void>;
  logout(): Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [admin, setAdmin] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Silent refresh on mount
  useEffect(() => {
    const initAuth = async () => {
      const token = getAccessToken();
      if (!token) {
        // Try to refresh
        const refreshed = await refreshAccessToken();
        if (!refreshed) {
          setIsLoading(false);
          return;
        }
      }
      // Fetch current admin
      try {
        const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/auth/me`, {
          headers: { Authorization: `Bearer ${getAccessToken()}` },
        });
        if (res.ok) {
          const data = await res.json();
          setAdmin(data);
        } else if (res.status === 401) {
          // Token expired, try refresh
          const refreshed = await refreshAccessToken();
          if (refreshed) {
            const retryRes = await fetch(
              `${process.env.NEXT_PUBLIC_API_URL}/admin/auth/me`,
              { headers: { Authorization: `Bearer ${getAccessToken()}` } }
            );
            if (retryRes.ok) {
              const data = await retryRes.json();
              setAdmin(data);
            } else {
              clearTokens();
            }
          } else {
            clearTokens();
          }
        }
      } catch {
        clearTokens();
      }
      setIsLoading(false);
    };

    initAuth();
  }, []);

  const login = async (email: string, password: string) => {
    setError(null);
    setIsLoading(true);
    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      if (!res.ok) {
        if (res.status === 401) {
          setError('Invalid email or password');
        } else {
          setError('Service unavailable');
        }
        throw new Error(`Login failed: ${res.status}`);
      }

      const data = await res.json();
      setTokens(data.accessToken, data.refreshToken);
      setAdmin(data.admin);
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    try {
      await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/auth/logout`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${getAccessToken()}` },
      });
    } catch {
      // Continue with logout even if API call fails
    }
    clearTokens();
    setAdmin(null);
  };

  return (
    <AuthContext.Provider value={{ admin, isLoading, error, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
```

### Permissions (`lib/auth/permissions.ts`)

Full RBAC implementation (B0 provided skeleton; this expands it).

```typescript
// lib/auth/permissions.ts
export type AdminRole = 'platformAdmin' | 'moderator' | 'eventOps';

export interface Permission {
  read: boolean;
  write: boolean;
}

// Navigation items each role can access
export const NAV_PERMISSIONS: Record<AdminRole, string[]> = {
  platformAdmin: ['/', '/users', '/events', '/customers', '/products', '/moderation', '/posh-orders', '/analytics', '/settings'],
  moderator: ['/', '/moderation'],
  eventOps: ['/', '/event-ops'],
};

// Fine-grained permissions per resource
export const ROLE_PERMISSIONS: Record<AdminRole, Record<string, Permission>> = {
  platformAdmin: {
    dashboard: { read: true, write: false },
    users: { read: true, write: true },
    events: { read: true, write: true },
    customers: { read: true, write: true },
    products: { read: true, write: true },
    moderation: { read: true, write: true },
    posh_orders: { read: true, write: true },
    analytics: { read: true, write: false },
    settings: { read: true, write: true },
  },
  moderator: {
    dashboard: { read: true, write: false },
    moderation: { read: true, write: true },
  },
  eventOps: {
    dashboard: { read: true, write: false },
    event_ops: { read: true, write: true },
  },
};

export function canAccess(
  role: AdminRole,
  resource: string,
  action: 'read' | 'write' = 'read'
): boolean {
  const perms = ROLE_PERMISSIONS[role]?.[resource];
  if (!perms) return false;
  return action === 'read' ? perms.read : perms.write;
}

export function canNavigateTo(role: AdminRole, path: string): boolean {
  const allowed = NAV_PERMISSIONS[role];
  if (!allowed) return false;
  return allowed.includes(path);
}
```

### Admin API Client (`lib/api/admin-api-client.ts`)

Wraps fetch with authorization header and auto-refresh.

```typescript
// lib/api/admin-api-client.ts
import { getAccessToken, refreshAccessToken, clearTokens } from '@/lib/auth/auth-client';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

interface FetchOptions extends RequestInit {
  skipAuth?: boolean;
}

async function fetchWithAuth(
  path: string,
  options: FetchOptions = {}
): Promise<Response> {
  const { skipAuth = false, ...restOptions } = options;

  const headers = new Headers(restOptions.headers || {});
  if (!skipAuth) {
    const token = getAccessToken();
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
    }
  }

  let res = await fetch(`${API_URL}${path}`, {
    ...restOptions,
    headers,
  });

  // Auto-refresh on 401
  if (res.status === 401 && !skipAuth) {
    const refreshed = await refreshAccessToken();
    if (refreshed) {
      const newToken = getAccessToken();
      headers.set('Authorization', `Bearer ${newToken}`);
      res = await fetch(`${API_URL}${path}`, {
        ...restOptions,
        headers,
      });
    } else {
      // Refresh failed, clear tokens and redirect to login
      clearTokens();
      // Caller handles redirect via useEffect watching auth state
    }
  }

  return res;
}

export const adminApiClient = {
  get: (path: string) => fetchWithAuth(path, { method: 'GET' }),
  post: (path: string, body?: unknown) =>
    fetchWithAuth(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    }),
  patch: (path: string, body?: unknown) =>
    fetchWithAuth(path, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    }),
  delete: (path: string) => fetchWithAuth(path, { method: 'DELETE' }),
};
```

### Sidebar Component (Updated)

Wire permission check into nav rendering.

```typescript
// components/layout/Sidebar.tsx
'use client';

import { useAuth } from '@/lib/auth/auth-context';
import { canNavigateTo } from '@/lib/auth/permissions';
import Link from 'next/link';

const NAV_ITEMS = [
  { path: '/', label: 'Dashboard' },
  { path: '/users', label: 'Users' },
  { path: '/events', label: 'Events' },
  { path: '/customers', label: 'Customers' },
  { path: '/products', label: 'Products' },
  { path: '/moderation', label: 'Moderation' },
  { path: '/posh-orders', label: 'Posh Orders' },
  { path: '/analytics', label: 'Analytics' },
  { path: '/settings', label: 'Settings' },
];

export function Sidebar() {
  const { admin } = useAuth();

  const visibleItems = NAV_ITEMS.filter(
    (item) => admin && canNavigateTo(admin.role, item.path)
  );

  return (
    <aside className="w-64 bg-muted border-r border-border p-4">
      <nav className="space-y-2">
        {visibleItems.map((item) => (
          <Link
            key={item.path}
            href={item.path}
            className="block px-4 py-2 rounded hover:bg-primary/10"
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
```

### Topbar Component (Updated)

Show admin name, role badge, and logout.

```typescript
// components/layout/Topbar.tsx
'use client';

import { useAuth } from '@/lib/auth/auth-context';
import { useRouter } from 'next/navigation';
import { LogOut } from 'lucide-react';

export function Topbar() {
  const { admin, logout } = useAuth();
  const router = useRouter();

  const handleLogout = async () => {
    await logout();
    router.push('/login');
  };

  return (
    <div className="flex items-center justify-between h-16 px-6 border-b border-border bg-card">
      <div className="flex items-center gap-4">
        <span className="text-lg font-semibold">{admin?.name || 'Admin'}</span>
        <span className="text-xs px-2 py-1 bg-primary/20 text-primary rounded">
          {admin?.role}
        </span>
      </div>
      <button
        onClick={handleLogout}
        className="flex items-center gap-2 px-3 py-2 rounded hover:bg-muted transition"
      >
        <LogOut size={18} />
        Logout
      </button>
    </div>
  );
}
```

### Protected Layout (`app/(dashboard)/layout.tsx`)

Wraps protected routes with auth guard and app shell.

```typescript
// app/(dashboard)/layout.tsx
'use client';

import { useAuth } from '@/lib/auth/auth-context';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Topbar } from '@/components/layout/Topbar';
import { canNavigateTo } from '@/lib/auth/permissions';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { admin, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !admin) {
      router.push('/login');
    }
  }, [admin, isLoading, router]);

  if (isLoading) {
    return <div className="flex items-center justify-center h-screen">Loading...</div>;
  }

  if (!admin) {
    return null; // Redirect in progress
  }

  // Additional: block access to routes outside permitted nav
  const pathname = typeof window !== 'undefined' ? window.location.pathname : '';
  if (pathname !== '/' && !canNavigateTo(admin.role, pathname)) {
    // Redirect to first permitted page
    useEffect(() => {
      router.push('/');
    }, [router]);
  }

  return (
    <div className="flex h-screen bg-background text-foreground">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Topbar />
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>
    </div>
  );
}
```

### Login Page (Fully Implemented)

`app/(auth)/login/page.tsx` — wire to real API.

```typescript
// app/(auth)/login/page.tsx
'use client';

import { useAuth } from '@/lib/auth/auth-context';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login, error, isLoading, admin } = useAuth();
  const router = useRouter();

  // If already logged in, redirect to dashboard
  useEffect(() => {
    if (admin) {
      router.push('/');
    }
  }, [admin, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login(email, password);
      // Success: redirect handled by useEffect watching admin state
      router.push('/');
    } catch {
      // Error shown via error state in UI
    }
  };

  return (
    <div className="flex items-center justify-center h-screen bg-background">
      <div className="w-full max-w-md p-8 rounded-lg border border-border bg-card">
        <h1 className="text-2xl font-bold mb-6 text-foreground">Admin Login</h1>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">Email</label>
            <Input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              placeholder="admin@industrynight.net"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-2">Password</label>
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              placeholder="••••••••"
            />
          </div>
          {error && (
            <div data-testid="login-error" className="text-sm text-destructive">
              {error}
            </div>
          )}
          <Button
            type="submit"
            disabled={isLoading}
            className="w-full"
          >
            {isLoading ? 'Logging in...' : 'Login'}
          </Button>
        </form>
      </div>
    </div>
  );
}
```

### Middleware (Enhanced)

Protect against direct navigation to protected routes.

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;
  const isLoginPage = pathname === '/login';

  // Note: Since tokens are in-memory (not cookies), we can't check them server-side
  // Client-side layout handles redirects. This middleware is a secondary safety check.
  // For production with cookies, check token here.

  if (isLoginPage) {
    // Could redirect if we had a valid token in cookie, but we're using memory storage
    return NextResponse.next();
  }

  // Protected routes will redirect via layout component
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api).*)'],
};
```

---

## Test Suite

### Unit Tests

Install Vitest or Jest if not already present. Create tests in `__tests__/` directory.

```typescript
// __tests__/permissions.test.ts
import { canAccess, canNavigateTo } from '@/lib/auth/permissions';

describe('canAccess', () => {
  it('platformAdmin can read/write all resources', () => {
    expect(canAccess('platformAdmin', 'users', 'read')).toBe(true);
    expect(canAccess('platformAdmin', 'users', 'write')).toBe(true);
    expect(canAccess('platformAdmin', 'customers', 'write')).toBe(true);
  });

  it('moderator can only read dashboard and write moderation', () => {
    expect(canAccess('moderator', 'dashboard', 'read')).toBe(true);
    expect(canAccess('moderator', 'dashboard', 'write')).toBe(false);
    expect(canAccess('moderator', 'moderation', 'write')).toBe(true);
    expect(canAccess('moderator', 'users', 'read')).toBe(false);
  });

  it('eventOps can read dashboard and write event_ops', () => {
    expect(canAccess('eventOps', 'dashboard', 'read')).toBe(true);
    expect(canAccess('eventOps', 'event_ops', 'write')).toBe(true);
    expect(canAccess('eventOps', 'customers', 'read')).toBe(false);
  });
});

describe('canNavigateTo', () => {
  it('platformAdmin can navigate to all paths', () => {
    expect(canNavigateTo('platformAdmin', '/')).toBe(true);
    expect(canNavigateTo('platformAdmin', '/customers')).toBe(true);
    expect(canNavigateTo('platformAdmin', '/settings')).toBe(true);
  });

  it('moderator can only navigate to dashboard and moderation', () => {
    expect(canNavigateTo('moderator', '/')).toBe(true);
    expect(canNavigateTo('moderator', '/moderation')).toBe(true);
    expect(canNavigateTo('moderator', '/users')).toBe(false);
    expect(canNavigateTo('moderator', '/events')).toBe(false);
  });

  it('eventOps can only navigate to dashboard and event-ops', () => {
    expect(canNavigateTo('eventOps', '/')).toBe(true);
    expect(canNavigateTo('eventOps', '/event-ops')).toBe(true);
    expect(canNavigateTo('eventOps', '/moderation')).toBe(false);
  });
});
```

```typescript
// __tests__/auth-client.test.ts
import {
  getAccessToken,
  setTokens,
  clearTokens,
  refreshAccessToken,
} from '@/lib/auth/auth-client';

describe('auth-client', () => {
  afterEach(() => {
    clearTokens();
  });

  it('setTokens and getAccessToken roundtrip', () => {
    setTokens('access123', 'refresh456');
    expect(getAccessToken()).toBe('access123');
  });

  it('clearTokens removes tokens', () => {
    setTokens('access123', 'refresh456');
    clearTokens();
    expect(getAccessToken()).toBeNull();
  });

  it('refreshAccessToken returns false on 401', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve(new Response('Unauthorized', { status: 401 }))
    );
    const result = await refreshAccessToken();
    expect(result).toBe(false);
  });

  it('refreshAccessToken returns true on 200 and updates token', async () => {
    setTokens('old_access', 'refresh456');
    global.fetch = jest.fn(() =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            accessToken: 'new_access',
            refreshToken: 'new_refresh',
          }),
          { status: 200, headers: { 'content-type': 'application/json' } }
        )
      )
    );
    const result = await refreshAccessToken();
    expect(result).toBe(true);
    expect(getAccessToken()).toBe('new_access');
  });
});
```

### End-to-End Tests (Playwright)

```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('unauthenticated user is redirected to login', async ({ page }) => {
    await page.goto('http://localhost:3630/');
    await expect(page).toHaveURL(/\/login/);
  });

  test('login with invalid credentials shows error', async ({ page }) => {
    await page.goto('http://localhost:3630/login');
    await page.fill('input[type=email]', 'wrong@example.com');
    await page.fill('input[type=password]', 'wrongpassword');
    await page.click('button[type=submit]');
    await expect(page.locator('[data-testid=login-error]')).toBeVisible();
  });

  test('login with valid credentials redirects to dashboard', async ({ page }) => {
    await page.goto('http://localhost:3630/login');
    const testEmail = process.env.TEST_ADMIN_EMAIL || 'admin@industrynight.net';
    const testPassword = process.env.TEST_ADMIN_PASSWORD || 'password123';
    await page.fill('input[type=email]', testEmail);
    await page.fill('input[type=password]', testPassword);
    await page.click('button[type=submit]');
    await expect(page).toHaveURL('http://localhost:3630/');
    await expect(page.locator('h1')).toContainText('Dashboard');
  });

  test('logout clears session and redirects to login', async ({ page }) => {
    await loginAs(page, 'platformAdmin');
    await page.click('button:has-text("Logout")');
    await expect(page).toHaveURL(/\/login/);
  });

  test('back button after logout stays on login page', async ({ page }) => {
    await loginAs(page, 'platformAdmin');
    await page.click('button:has-text("Logout")');
    await page.goBack();
    await expect(page).toHaveURL(/\/login/);
  });
});

test.describe('RBAC Navigation', () => {
  test('platformAdmin sees all nav items', async ({ page }) => {
    await loginAs(page, 'platformAdmin');
    await expect(page.locator('nav a:has-text("Users")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Customers")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Analytics")')).toBeVisible();
  });

  test('moderator sees only dashboard and moderation', async ({ page }) => {
    await loginAs(page, 'moderator');
    await expect(page.locator('nav a:has-text("Dashboard")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Moderation")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Users")')).not.toBeVisible();
    await expect(page.locator('nav a:has-text("Customers")')).not.toBeVisible();
  });

  test('eventOps sees only dashboard and event-ops', async ({ page }) => {
    await loginAs(page, 'eventOps');
    await expect(page.locator('nav a:has-text("Dashboard")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Event Ops")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Moderation")')).not.toBeVisible();
  });

  test('moderator accessing /users redirects to /', async ({ page }) => {
    await loginAs(page, 'moderator');
    await page.goto('http://localhost:3630/users');
    // Should redirect to /
    await expect(page).toHaveURL('http://localhost:3630/');
  });
});

async function loginAs(page: any, role: string) {
  // Assume test credentials exist in env or test data
  const credentials: Record<string, { email: string; password: string }> = {
    platformAdmin: {
      email: process.env.TEST_ADMIN_EMAIL || 'admin@industrynight.net',
      password: process.env.TEST_ADMIN_PASSWORD || 'password123',
    },
    moderator: {
      email: process.env.TEST_MODERATOR_EMAIL || 'moderator@industrynight.net',
      password: process.env.TEST_MODERATOR_PASSWORD || 'password123',
    },
    eventOps: {
      email: process.env.TEST_EVENTOPS_EMAIL || 'eventops@industrynight.net',
      password: process.env.TEST_EVENTOPS_PASSWORD || 'password123',
    },
  };
  const cred = credentials[role];
  await page.goto('http://localhost:3630/login');
  await page.fill('input[type=email]', cred.email);
  await page.fill('input[type=password]', cred.password);
  await page.click('button[type=submit]');
  await page.waitForURL('http://localhost:3630/');
}
```

---

## Definition of Done

- [ ] Login form submits real credentials to `POST /api/admin/auth/login`
- [ ] Access token + refresh token stored in memory (module-level variables)
- [ ] On 401: inline error message shown; form NOT cleared
- [ ] Authorization header injected on all authenticated requests
- [ ] Auto-refresh happens before expiry (60s buffer) and on 401 retry
- [ ] Silent refresh on page reload: user stays logged in if token still valid
- [ ] Logout clears tokens, redirects to `/login`, prevents back-button auth leak
- [ ] All three roles visible with correct nav items (platformAdmin > moderator/eventOps)
- [ ] Unauthorized nav access redirects to first permitted page
- [ ] `npm test` passes all permission + auth-client tests
- [ ] Playwright e2e tests pass: login, logout, rbac redirect, role-gated nav
- [ ] No TypeScript errors: `npm run type-check`
- [ ] No console errors during auth flow
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/B1-auth-rbac-[claude|gpt]`
**Model used:** —
**Date completed:** —

### What I implemented exactly as specced
-

### What I deviated from the spec and why
-

### What I deferred or left incomplete
-

### Technical debt introduced
-

### What B2 (Dashboard + Stats) should know about this auth system
-

---

## Interrogative Session

**Q1 (Agent):** Did token refresh behavior feel right — the 60-second pre-refresh, the 401-retry-once pattern, the memory-only storage? Any concerns before handing to B2?
> Jeff:

**Q2 (Agent):** The permissions.ts structure — does it scale to future roles? Would you want a more dynamic system, or is this hardcoded map the right approach?
> Jeff:

**Q3 (Agent):** Role-to-nav mapping is one-way (role determines what's visible). Should we have a complementary check (route checks if current role is allowed)? Already there via canNavigateTo?
> Jeff:

**Q4 (Agent):** Silent refresh on page reload is nice UX, but if the refresh token has been compromised, the attacker could potentially keep the session alive. Should we add a max session duration or force re-login after N hours?
> Jeff:

**Q5 (Agent):** Test coverage — should B2 add an integration test that logs in as each role, navigates all paths, and verifies the right subset is accessible?
> Jeff:

**Q6 (Jeff):** How confident are you that the token expiry parsing (extractExpiresIn) is correct? Should we use a library like `jwt-decode`?

**Q7 (Jeff):** The error message "Invalid email or password" is intentionally vague to prevent user enumeration — good. But should we also rate-limit failed login attempts server-side?

**Q8 (Jeff):** When a moderator tries to access `/users` and gets redirected to `/`, will there be a 404 page briefly, or does the redirect happen cleanly before render?

**Ready for review:** ☐ Yes
