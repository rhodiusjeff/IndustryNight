# [Track-B0] React Admin — Project Scaffold & Design System

**Track:** B (React Admin)
**Sequence:** 1 of 4 in Track B
**Model:** claude-opus-4-6
**Alternate Model:** gpt-5.4 ← the stronger OpenAI choice for this prompt specifically; architectural scaffolding involves chaining many tools (npm install, type-check, test run, build verify) where GPT-5.4's tool orchestration score (54.6% vs 51.9%) matters more than GPT-5.3-Codex's terminal advantage. Do NOT use GPT-5.4 mini for B0 — the architectural decisions made here propagate through all of Track B.
**A/B Test:** Yes ⚡ — run both models on `feature/B0-react-scaffold-claude` and `feature/B0-react-scaffold-gpt`; adversarial panel review before merging to `integration`. **Highest-impact A/B in the library** — B1, B2, B3 all build on this foundation.
**Estimated Effort:** Medium (1-2 days)
**Dependencies:** None — runs in parallel with C0 and A0. However, complete C0 before starting B1.

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (infrastructure section, deployment patterns, existing scripts)
- `docs/product/master_plan_v2.md` — Section 5 (React Admin Architecture Spec) — especially §5.1 (Tech Stack), §5.2 (Design System), §5.3 (Navigation Structure), §5.10 (Local Dev Scripts), §5.13 (Auth & Session)
- `docs/design/admin-mockup.html` — the interactive prototype; this is the visual target
- `scripts/run-api.sh` — pattern to follow for the new run-react-admin.sh script
- `packages/admin-app/` — the existing Flutter admin (reference for what features will be built; don't copy code, just understand the scope)
- `scripts/deploy-admin.sh` — existing Flutter deploy pattern to understand what the new React deploy will mirror

---

## Goal

Scaffold a complete, deployable Next.js admin application at `packages/react-admin/` with the Industry Night dark design system, role-gated navigation shell, admin authentication, and a functional Dashboard screen. Also create the local development scripts. At the end of this prompt, a developer can run `./scripts/run-react-admin.sh` on port 3630, log in with admin credentials, see the dashboard, and navigate a fully-structured (but mostly empty) sidebar. Nothing else is wired yet — that's B1+.

---

## Acceptance Criteria

**Project setup:**
- [ ] `packages/react-admin/` exists as a valid Next.js 14+ App Router project with TypeScript strict mode
- [ ] `packages/react-admin/package.json` includes: next, react, react-dom, tailwindcss, @shadcn/ui (or radix-ui primitives), framer-motion, react-query (@tanstack/react-query), zustand, clsx, lucide-react
- [ ] `packages/react-admin/.env.local.template` exists with documented variables: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_APP_ENV`
- [ ] `scripts/run-react-admin.sh` exists, is executable, runs on port **3630**, creates `.env.local` from template if missing, accepts `--env dev|prod` flag
- [ ] `scripts/debug-react-admin.sh` exists, sets `NODE_OPTIONS='--inspect'`, runs on port 3630
- [ ] `npm run dev` in `packages/react-admin/` starts the app on port 3630

**Design system:**
- [ ] Tailwind config has all custom design tokens: background (#121212), foreground (#FFFFFF), primary (#7C3AED), primary-light (#A855F7), accent (#FF3D8E), secondary (#1B9CFC), verification (#F1C40F), success (#10B981), warning (#F59E0B), destructive (#EF4444)
- [ ] Inter font loaded via `next/font/google`
- [ ] `globals.css` uses CSS custom properties for all color tokens
- [ ] shadcn/ui components initialized with the dark theme variant
- [ ] A `Storybook`-style dev page at `/dev/components` renders the core component set (optional but recommended)

**Authentication:**
- [ ] `/login` route renders an email/password form
- [ ] On submit, calls `POST /api/admin/auth/login` (proxied to `NEXT_PUBLIC_API_URL`)
- [ ] On success, stores `accessToken` and `refreshToken` in httpOnly cookie (or secure localStorage if cookie approach is problematic in Next.js App Router)
- [ ] On failure (401), shows inline error: "Invalid email or password"
- [ ] All routes except `/login` redirect to `/login` if not authenticated
- [ ] Authenticated routes redirect `/login` → `/` (dashboard)

**Role-gated navigation shell:**
- [ ] App shell (`layout.tsx`) renders: sidebar + topbar + main content area
- [ ] Sidebar shows navigation items filtered by authenticated admin's role:
  - `eventOps` — sees only: Dashboard, Event Ops, Events (read)
  - `moderator` — sees only: Dashboard, Users (read), Moderation
  - `platformAdmin` — sees all sections
- [ ] Topbar shows: current admin's name/email, role badge, logout button
- [ ] Logout clears tokens and redirects to `/login`
- [ ] Sidebar is collapsible to icon-only mode (toggle button)
- [ ] Layout is responsive: sidebar collapses to overlay drawer on viewport < 768px

**Dashboard screen:**
- [ ] `/` renders a Dashboard screen with 4 stat cards: Total Users, Active Events, Connections Made, Community Posts
- [ ] Stats are fetched from `GET /admin/dashboard` with `Authorization: Bearer {accessToken}`
- [ ] Loading state: skeleton cards while fetching
- [ ] Error state: "Failed to load stats" with a retry button
- [ ] Data displayed with proper number formatting (e.g., 1,234 not 1234)

**Other screens (empty states):**
- [ ] All sidebar navigation links route to their correct paths without 404
- [ ] Non-implemented screens show a placeholder: "Coming soon — [Screen Name]" in the center of the content area
- [ ] No broken links or console errors on navigation

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin, I can log in with my email and password and see all admin sections in the sidebar | Full access |
| Moderator | As a moderator admin, after login I only see Dashboard, Users, and Moderation in the sidebar — nothing else | Role gate |
| Event Ops staff | As an eventOps staff member, after login I only see Dashboard, Event Ops, and Events — nothing else | Role gate |
| Any admin | As any admin user, if my session expires and I navigate to a protected page, I am redirected to login automatically | Silent auth expiry |
| Any admin | As any admin user, clicking Logout clears my session and takes me to the login screen | |
| Developer | As a developer, I can run `./scripts/run-react-admin.sh` to start the app on port 3630 without manual env setup | Dev ergonomics |
| Developer | As a developer, I can run `./scripts/run-react-admin.sh --env prod` to point at the production API | Multi-env support |
| System | As the API, I receive `Authorization: Bearer {token}` on all authenticated requests from the React admin | Standard JWT pattern |

---

## Technical Spec

### File & Directory Structure

```
packages/react-admin/
├── app/                          # Next.js App Router
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx          # Login form
│   ├── (dashboard)/              # Protected routes group
│   │   ├── layout.tsx            # AppShell (sidebar + topbar)
│   │   ├── page.tsx              # Dashboard
│   │   ├── event-ops/page.tsx    # Event Ops (Coming Soon)
│   │   ├── users/page.tsx        # Users (Coming Soon)
│   │   ├── events/page.tsx       # Events (Coming Soon)
│   │   ├── customers/page.tsx    # Customers (Coming Soon)
│   │   ├── jobs/page.tsx         # Jobs (Coming Soon)
│   │   ├── moderation/page.tsx   # Moderation (Coming Soon)
│   │   ├── posh-orders/page.tsx  # Posh Orders (Coming Soon)
│   │   ├── analytics/page.tsx    # Analytics (Coming Soon)
│   │   └── settings/page.tsx     # Settings (Coming Soon)
│   ├── api/                      # Next.js API routes (proxy to backend)
│   │   └── [...path]/route.ts    # Generic proxy route
│   ├── globals.css
│   └── layout.tsx                # Root layout (fonts, providers)
├── components/
│   ├── ui/                       # shadcn/ui components (auto-generated)
│   ├── layout/
│   │   ├── Sidebar.tsx
│   │   ├── Topbar.tsx
│   │   └── AppShell.tsx
│   ├── dashboard/
│   │   └── StatCard.tsx
│   └── common/
│       ├── SkeletonCard.tsx
│       ├── EmptyState.tsx
│       └── ComingSoon.tsx
├── lib/
│   ├── api/
│   │   └── client.ts             # Fetch wrapper with auth + token refresh
│   ├── auth/
│   │   └── session.ts            # Token storage + session helpers
│   ├── permissions.ts            # Role → permission map (see master_plan_v2.md §5.5)
│   └── utils.ts                  # cn(), formatNumber(), etc.
├── hooks/
│   ├── useAuth.ts                # Auth state, login, logout
│   └── useDashboard.ts           # React Query hook for dashboard stats
├── providers/
│   └── QueryProvider.tsx         # TanStack Query provider
├── types/
│   └── admin.ts                  # AdminUser, DashboardStats types
├── middleware.ts                 # Next.js middleware for auth redirect
├── tailwind.config.ts
├── next.config.js
├── tsconfig.json
└── package.json
```

### Tailwind Config Design Tokens

```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class',
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background: '#121212',
        foreground: '#FFFFFF',
        primary: {
          DEFAULT: '#7C3AED',
          light: '#A855F7',
          foreground: '#FFFFFF',
        },
        accent: '#FF3D8E',
        secondary: '#1B9CFC',
        verification: '#F1C40F',
        success: '#10B981',
        warning: '#F59E0B',
        destructive: {
          DEFAULT: '#EF4444',
          foreground: '#FFFFFF',
        },
        muted: {
          DEFAULT: '#1E1E1E',
          foreground: '#A1A1AA',
        },
        border: '#2A2A2A',
        card: '#1A1A1A',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
}
export default config
```

### Permissions Map

```typescript
// lib/permissions.ts
export type AdminRole = 'platformAdmin' | 'moderator' | 'eventOps';

export const NAV_PERMISSIONS: Record<string, AdminRole[]> = {
  '/':             ['platformAdmin', 'moderator', 'eventOps'],
  '/event-ops':    ['platformAdmin', 'eventOps'],
  '/users':        ['platformAdmin', 'moderator'],
  '/events':       ['platformAdmin', 'eventOps'],
  '/customers':    ['platformAdmin'],
  '/jobs':         ['platformAdmin', 'moderator'],
  '/moderation':   ['platformAdmin', 'moderator'],
  '/posh-orders':  ['platformAdmin', 'eventOps'],
  '/analytics':    ['platformAdmin'],
  '/settings':     ['platformAdmin'],
};

export function canAccess(role: AdminRole, path: string): boolean {
  const allowed = NAV_PERMISSIONS[path];
  if (!allowed) return role === 'platformAdmin'; // unknown paths: platformAdmin only
  return allowed.includes(role);
}
```

### Auth Middleware

```typescript
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('accessToken')?.value
  const isLoginPage = request.nextUrl.pathname === '/login'

  if (!token && !isLoginPage) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  if (token && isLoginPage) {
    return NextResponse.redirect(new URL('/', request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api).*)'],
}
```

### API Proxy Pattern

Use Next.js API route as a proxy to avoid CORS in development:

```typescript
// app/api/[...path]/route.ts
import { NextRequest } from 'next/server'

export async function GET(req: NextRequest, { params }: { params: { path: string[] } }) {
  return proxyRequest(req, params.path, 'GET')
}
// repeat for POST, PATCH, DELETE, PUT

async function proxyRequest(req: NextRequest, pathSegments: string[], method: string) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL
  const path = pathSegments.join('/')
  const target = `${apiUrl}/${path}${req.nextUrl.search}`

  const headers = new Headers()
  const auth = req.headers.get('authorization')
  if (auth) headers.set('authorization', auth)
  headers.set('content-type', req.headers.get('content-type') || 'application/json')

  const body = method !== 'GET' ? await req.text() : undefined
  const response = await fetch(target, { method, headers, body })
  const data = await response.text()

  return new Response(data, {
    status: response.status,
    headers: { 'content-type': response.headers.get('content-type') || 'application/json' },
  })
}
```

### Local Dev Scripts

```bash
#!/bin/bash
# scripts/run-react-admin.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REACT_ADMIN_DIR="$SCRIPT_DIR/../packages/react-admin"
ENV="dev"
PORT=3630

# Parse flags
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Set API URL based on environment
if [ "$ENV" = "prod" ]; then
  API_URL="https://api.industrynight.net"
else
  API_URL="http://localhost:3000"
fi

# Bootstrap .env.local from template if it doesn't exist
ENV_FILE="$REACT_ADMIN_DIR/.env.local"
TEMPLATE_FILE="$REACT_ADMIN_DIR/.env.local.template"
if [ ! -f "$ENV_FILE" ] && [ -f "$TEMPLATE_FILE" ]; then
  echo "Creating .env.local from template..."
  cp "$TEMPLATE_FILE" "$ENV_FILE"
  sed -i "s|NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=$API_URL|" "$ENV_FILE"
  sed -i "s|NEXT_PUBLIC_APP_ENV=.*|NEXT_PUBLIC_APP_ENV=$ENV|" "$ENV_FILE"
  echo ".env.local created. Edit it if needed, then re-run."
fi

echo "Starting React Admin on http://localhost:$PORT (env: $ENV)"
cd "$REACT_ADMIN_DIR" && PORT=$PORT npm run dev
```

```bash
#!/bin/bash
# scripts/debug-react-admin.sh
# Same as run-react-admin.sh but with Node.js inspector enabled

export NODE_OPTIONS='--inspect'
"$(dirname "${BASH_SOURCE[0]}")/run-react-admin.sh" "$@"
```

### Dashboard Stats Type

```typescript
// types/admin.ts
export interface DashboardStats {
  totalUsers: number;
  activeEvents: number;
  totalConnections: number;
  totalPosts: number;
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: 'platformAdmin' | 'moderator' | 'eventOps';
}
```

---

## Test Suite

### Unit Tests

Install and configure Vitest (or Jest) for the React admin:

```typescript
// packages/react-admin/__tests__/permissions.test.ts
import { canAccess } from '../lib/permissions'

describe('canAccess', () => {
  it('platformAdmin can access all routes', () => {
    expect(canAccess('platformAdmin', '/')).toBe(true);
    expect(canAccess('platformAdmin', '/settings')).toBe(true);
    expect(canAccess('platformAdmin', '/analytics')).toBe(true);
    expect(canAccess('platformAdmin', '/customers')).toBe(true);
  });

  it('eventOps can access event-ops and events but not customers or moderation', () => {
    expect(canAccess('eventOps', '/')).toBe(true);
    expect(canAccess('eventOps', '/event-ops')).toBe(true);
    expect(canAccess('eventOps', '/events')).toBe(true);
    expect(canAccess('eventOps', '/customers')).toBe(false);
    expect(canAccess('eventOps', '/moderation')).toBe(false);
    expect(canAccess('eventOps', '/analytics')).toBe(false);
    expect(canAccess('eventOps', '/settings')).toBe(false);
  });

  it('moderator can access users and moderation but not events or customers', () => {
    expect(canAccess('moderator', '/')).toBe(true);
    expect(canAccess('moderator', '/users')).toBe(true);
    expect(canAccess('moderator', '/moderation')).toBe(true);
    expect(canAccess('moderator', '/events')).toBe(false);
    expect(canAccess('moderator', '/customers')).toBe(false);
    expect(canAccess('moderator', '/settings')).toBe(false);
  });
});
```

```typescript
// packages/react-admin/__tests__/StatCard.test.tsx
import { render, screen } from '@testing-library/react'
import StatCard from '../components/dashboard/StatCard'

describe('StatCard', () => {
  it('renders label and formatted value', () => {
    render(<StatCard label="Total Users" value={1234} />)
    expect(screen.getByText('Total Users')).toBeInTheDocument();
    expect(screen.getByText('1,234')).toBeInTheDocument();
  });

  it('renders skeleton when loading', () => {
    render(<StatCard label="Total Users" value={0} loading={true} />)
    expect(screen.getByTestId('stat-skeleton')).toBeInTheDocument();
  });
});
```

### End-to-End Tests (Playwright — setup in this prompt, run later)

```typescript
// packages/react-admin/e2e/auth.spec.ts
import { test, expect } from '@playwright/test'

test('unauthenticated user is redirected to login', async ({ page }) => {
  await page.goto('http://localhost:3630/');
  await expect(page).toHaveURL(/\/login/);
});

test('login with invalid credentials shows error', async ({ page }) => {
  await page.goto('http://localhost:3630/login');
  await page.fill('[name=email]', 'wrong@example.com');
  await page.fill('[name=password]', 'wrongpassword');
  await page.click('button[type=submit]');
  await expect(page.locator('[data-testid=login-error]')).toBeVisible();
});

test('login with valid credentials redirects to dashboard', async ({ page }) => {
  await page.goto('http://localhost:3630/login');
  await page.fill('[name=email]', process.env.TEST_ADMIN_EMAIL!);
  await page.fill('[name=password]', process.env.TEST_ADMIN_PASSWORD!);
  await page.click('button[type=submit]');
  await expect(page).toHaveURL('http://localhost:3630/');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
```

### Smoke Tests (post-deploy)

```bash
# Add to deploy-admin.sh (for React admin equivalent when created)
# Verify login page loads
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$REACT_ADMIN_URL/login")
[ "$RESPONSE" = "200" ] || (echo "FAIL: login page returned $RESPONSE" && exit 1)

# Verify protected routes redirect (not 200)
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$REACT_ADMIN_URL/")
[ "$RESPONSE" = "307" ] || [ "$RESPONSE" = "302" ] || \
  (echo "FAIL: dashboard not redirecting unauthenticated users (got $RESPONSE)" && exit 1)

echo "✓ B0 smoke tests passed"
```

---

## Definition of Done

- [ ] `packages/react-admin/` committed with all scaffold files
- [ ] `scripts/run-react-admin.sh` and `scripts/debug-react-admin.sh` created, executable, and committed
- [ ] `npm run dev` in `packages/react-admin/` starts on port 3630 without errors
- [ ] Login form renders at `/login`; dashboard renders at `/` after login
- [ ] Role-gated sidebar: eventOps sees only 3 sections, moderator sees only 3, platformAdmin sees all
- [ ] Unit tests pass: `npm test` in `packages/react-admin/`
- [ ] Dashboard shows real stats when connected to dev API
- [ ] No TypeScript strict mode errors (`npm run type-check`)
- [ ] No console errors or warnings in browser during basic navigation
- [ ] `.env.local.template` committed (`.env.local` itself in `.gitignore`)
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff
- [ ] (A/B) Adversarial panel review complete — see `docs/codex/reviews/B0-adversarial-review.md`

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/B0-react-scaffold-[claude|gpt]`
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

### What B1 (Auth + RBAC) should know about this scaffold
-

---

## Interrogative Session

**Q1: Does the app shell feel right — navigation, dark theme, role-gated sidebar? Does it match the mockup in docs/design/admin-mockup.html?**
> Jeff:

**Q2: Any structural choices that feel off — file layout, component names, how auth works — that acceptance criteria wouldn't surface?**
> Jeff:

**Q3: Any concerns before adversarial review? Note: B1, B2, B3 all build on whichever branch wins here.**
> Jeff:

**Ready for review:** ☐ Yes
