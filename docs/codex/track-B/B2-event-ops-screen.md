# [Track-B2] React Admin — Event Ops Screen (Real-Time Check-In Dashboard)

**Track:** B (React Admin)
**Sequence:** 3 of 4 in Track B
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4
**A/B Test:** No
**Estimated Effort:** Medium
**Dependencies:** B1 (auth + RBAC), C1 (missing API endpoints), C2 (push notifications)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — project reference (database schema, API routes, roles)
- `docs/codex/track-B/B0-scaffold-design-system.md` — design system, component patterns, styling conventions
- `docs/codex/track-B/B1-auth-rbac-permissions.md` — role-gated navigation, `eventOps` role definition, auth hooks
- `docs/codex/track-C/C1-missing-api-endpoints.md` — backend SSE stream format, check-in payload structure, ticket resolution
- `docs/codex/track-C/C2-push-notifications.md` — FCM integration, push notification payload for wristband confirmation

---

## Goal

Build the Event Ops screen — the real-time check-in dashboard used by `eventOps` staff on event night, typically on a tablet at the venue door. The screen shows live attendee check-ins via Server-Sent Events (SSE), allows wristband confirmation with one tap, displays a queue of unmatched Posh buyers, and provides venue staff with the activation code to share with walk-in guests.

At the end of this prompt, an eventOps-role admin can navigate to `/events/ops/[eventId]` and see check-ins streaming in real-time, confirm wristbands with live FCM notifications, resolve Posh exceptions, and view the activation code prominently.

---

## Acceptance Criteria

**SSE Stream & Real-Time Updates**
- [ ] `GET /admin/events/:id/checkins/stream` endpoint (backend, C1) returns `text/event-stream` content type
- [ ] On SSE connect, client receives snapshot of last 50 check-ins immediately
- [ ] Subsequent check-in events arrive within 5 seconds of app check-in (5-second polling interval on backend)
- [ ] Event format matches spec: `checkin`, `wristband`, `heartbeat` event types with proper data payloads
- [ ] Heartbeat every 30 seconds keeps connection alive (prevents proxy timeout)
- [ ] Client auto-reconnects with exponential backoff (1s, 2s, 4s, 8s, max 30s) on disconnect

**Event Selector**
- [ ] `/events/ops/` route shows event selector (dropdown or card list)
- [ ] Displays only active/upcoming events (status: published, not completed/cancelled)
- [ ] For `eventOps` role: auto-selects soonest upcoming/currently-running event if only one active
- [ ] Navigates to `/events/ops/[eventId]` on selection
- [ ] Event cards show: event name, date/time, status badge

**Main Event Ops Screen Layout**
- [ ] Left column (mobile: full-width tab): Live check-in stream
  - Header: event name, date/time, total check-in count (auto-updating)
  - Auto-scrolling feed (newest at top)
  - Each entry: avatar + name + specialty + time ("2m ago")
  - Badge: "Posh" if `posh_order_id` present; "Walk-in" if from `tickets` table
  - Wristband status icon: ⬜ (pending) → ✅ (issued)
  - New arrivals animate in from top with highlight fade (2 second highlight, 1 second fade)

- [ ] Right column (mobile: tab): Stats + Exceptions
  - Stats cards: Total Check-ins, Wristbands Issued, Posh Buyers, Walk-ins (derived from checkins array, no separate API call)
  - Posh Exception Queue: unmatched `posh_orders` (user_id IS NULL)
    - Each exception: buyer name, phone (last 4), ticket type, created_at
    - "Resolve" button → modal with user search (by name/phone) → select → `PATCH /admin/posh-exceptions/:id/resolve`
    - Exception disappears from list after resolve (optimistic update)
  - Activation Code card: large monospace display (text-4xl) of `events.activation_code`
    - Copy-to-clipboard button with success toast
    - (Optional future): QR code generation from activation_code

- [ ] Bottom bar (mobile ≤ 640px): Tabbed navigation
  - Tabs: "Live Feed" | "Exceptions" | "Stats"
  - Only one tab visible at a time on narrow screens

**Wristband Confirmation**
- [ ] Tap wristband icon on check-in entry: optimistic ✅ update
- [ ] Call `PATCH /admin/events/:id/attendees/:ticketId/wristband` with `{ wristbandIssuedAt: now }`
- [ ] On success: entry icon becomes ✅; FCM push sent to attendee (C2)
- [ ] On error: revert optimistic update; show toast error
- [ ] Debounce: prevent double-tap within 2 seconds per ticket

**Error Handling & States**
- [ ] SSE connection error: show banner "Disconnected from venue stream. Reconnecting…"
- [ ] Failed wristband confirm: toast "Failed to issue wristband. Try again."
- [ ] Failed Posh resolve: toast with error message
- [ ] Network interruption: auto-reconnect, no manual intervention needed
- [ ] All errors auto-dismiss after 5 seconds or on user action

**Mobile Optimization**
- [ ] Viewport meta: width=device-width, initial-scale=1 (Next.js default)
- [ ] Touch-friendly tap targets: ≥ 44px height for wristband button
- [ ] Responsive: tablet portrait → desktop two-column; phone (≤ 640px) → tabbed single-column
- [ ] Dark theme (from B0 design system): #121212 background, easy on eyes in dim venue lighting
- [ ] No horizontal scroll; text wraps intelligently

**Permission & Navigation**
- [ ] Only `eventOps` role can see Event Ops in sidebar (from B1 RBAC)
- [ ] `platformAdmin` can also access Event Ops (read-only)
- [ ] Clicking sidebar → `/events/ops` → event selector or `/events/ops/[eventId]` if auto-selected
- [ ] Cannot access from non-eventOps roles: 403 redirect or sidebar item hidden

**Activation Code**
- [ ] Fetch from `GET /admin/events/:id` → `activation_code` field
- [ ] Display in prominent card: large monospace font, centered
- [ ] Copy-to-clipboard: click icon → copy code to clipboard → toast "Copied!" (dismiss 2s)
- [ ] (Future enhancement, not required): QR code image for projector/signage display

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| eventOps staff (tablet) | As eventOps at the venue door, I see attendees checking in live as they scan the app | Real-time SSE stream |
| eventOps staff | When I hand someone a wristband, I tap their entry to confirm — they get a push notification welcoming them | One-tap wristband confirm + FCM |
| eventOps staff | When a Posh buyer shows their confirmation email but has no app account, I find them in the exception queue and resolve it | Posh exception handling |
| Venue manager | I can read the activation code off the screen and tell walk-in guests what to enter in the app | Large, prominent code display |
| eventOps (phone backup) | On a phone, tabbed mobile view gives me full access to live feed and exceptions | Responsive design |
| Developer | I can run tests locally: `npm test` in packages/react-admin, all E2E green | Test suite |
| Platform Admin | I can access Event Ops in read-only mode (watch check-ins but not confirm wristbands) | RBAC enforcement |

---

## Technical Spec

### File & Directory Structure

```
packages/react-admin/
├── app/
│   ├── (dashboard)/
│   │   ├── events/
│   │   │   ├── ops/
│   │   │   │   ├── page.tsx              # Event selector screen
│   │   │   │   └── [eventId]/
│   │   │   │       └── page.tsx          # Main Event Ops screen
│   ├── api/
│   │   └── [...path]/route.ts            # Updated proxy for SSE support
├── components/
│   ├── event-ops/
│   │   ├── EventSelector.tsx             # Event card list/dropdown
│   │   ├── CheckinFeed.tsx               # Live check-in stream (left column)
│   │   ├── CheckinEntry.tsx              # Single check-in item with wristband button
│   │   ├── EventOpsStats.tsx             # Stats cards (right column)
│   │   ├── PoshExceptionQueue.tsx        # Posh exception list + resolve modal
│   │   ├── ActivationCodeCard.tsx        # Activation code display + copy button
│   │   ├── EventOpsLayout.tsx            # Two-column layout (desktop) / tabs (mobile)
│   │   └── EventOpsError.tsx             # Connection error banner
├── hooks/
│   └── use-event-checkins.ts             # SSE client hook (useEventCheckins)
├── types/
│   └── event-ops.ts                      # CheckinEntry, PoshException, EventOpsState types
└── lib/
    ├── api/
    │   └── client.ts                     # Extend with SSE support (EventSource wrapper)
```

### Types

```typescript
// types/event-ops.ts

export interface CheckinEntry {
  ticketId: string;
  userId?: string;
  name: string;
  photoUrl?: string;
  specialty?: string;
  checkedInAt: string;            // ISO timestamp
  poshOrderId?: string;            // null if walk-in
  wristbandIssuedAt?: string | null; // null = pending, ISO = issued
  source: 'posh' | 'walkin';      // derived from presence of poshOrderId
}

export interface PoshException {
  id: string;
  poshOrderId: string;
  buyerName: string;
  buyerPhone: string;
  ticketType: string;
  createdAt: string;
  eventId: string;
}

export interface EventOpsState {
  checkins: CheckinEntry[];
  totalCheckinCount: number;
  poshExceptions: PoshException[];
  isConnected: boolean;
  error: string | null;
  wristbandsPending: Record<string, boolean>; // ticketId -> is-loading
}

export interface SSECheckinEvent {
  event: 'checkin' | 'wristband' | 'heartbeat';
  data: {
    ticketId?: string;
    userId?: string;
    name?: string;
    photoUrl?: string;
    specialty?: string;
    checkedInAt?: string;
    poshOrderId?: string | null;
    wristbandIssuedAt?: string;
    timestamp?: string;
    totalCheckins?: number;
  };
}
```

### Hook: useEventCheckins

```typescript
// hooks/use-event-checkins.ts

import { useEffect, useRef, useState } from 'react';

interface UseEventCheckinsOptions {
  eventId: string;
  onError?: (error: string) => void;
}

export function useEventCheckins(options: UseEventCheckinsOptions) {
  const { eventId, onError } = options;
  const [state, setState] = useState({
    checkins: [] as CheckinEntry[],
    totalCount: 0,
    isConnected: false,
    error: null as string | null,
  });

  const eventSourceRef = useRef<EventSource | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const reconnectDelayRef = useRef(1000); // ms, doubles each retry, max 30s

  useEffect(() => {
    let isMounted = true;

    function connect() {
      if (!isMounted) return;

      try {
        const token = getCookie('accessToken'); // from B1 auth
        const eventSource = new EventSource(
          `/api/admin/events/${eventId}/checkins/stream?token=${encodeURIComponent(token)}`
        );

        eventSource.addEventListener('checkin', (event: MessageEvent) => {
          if (!isMounted) return;
          const data = JSON.parse(event.data) as CheckinEntry;
          setState((prev) => ({
            ...prev,
            checkins: [data, ...prev.checkins],
            totalCount: prev.totalCount + 1,
            isConnected: true,
            error: null,
          }));
          reconnectDelayRef.current = 1000; // reset backoff on success
        });

        eventSource.addEventListener('wristband', (event: MessageEvent) => {
          if (!isMounted) return;
          const { ticketId, wristbandIssuedAt } = JSON.parse(event.data);
          setState((prev) => ({
            ...prev,
            checkins: prev.checkins.map((c) =>
              c.ticketId === ticketId
                ? { ...c, wristbandIssuedAt }
                : c
            ),
          }));
        });

        eventSource.addEventListener('heartbeat', () => {
          if (!isMounted) return;
          setState((prev) => ({ ...prev, isConnected: true }));
        });

        eventSource.onerror = () => {
          if (!isMounted) return;
          eventSource.close();
          setState((prev) => ({
            ...prev,
            isConnected: false,
            error: 'Disconnected from venue stream',
          }));
          onError?.('Disconnected from venue stream. Reconnecting…');

          // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
          const delay = Math.min(reconnectDelayRef.current, 30000);
          reconnectTimeoutRef.current = setTimeout(() => {
            reconnectDelayRef.current = Math.min(
              reconnectDelayRef.current * 2,
              30000
            );
            connect();
          }, delay);
        };

        eventSourceRef.current = eventSource;
        setState((prev) => ({ ...prev, isConnected: true, error: null }));
      } catch (err) {
        if (isMounted) {
          setState((prev) => ({
            ...prev,
            error: 'Failed to connect to check-in stream',
          }));
          onError?.('Failed to connect to check-in stream');
        }
      }
    }

    connect();

    return () => {
      isMounted = false;
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, [eventId, onError]);

  return state;
}

function getCookie(name: string): string {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop()?.split(';').shift() || '';
  return '';
}
```

### Component: CheckinEntry

```typescript
// components/event-ops/CheckinEntry.tsx

import { useState } from 'react';
import { format } from 'date-fns';
import { CheckinEntry as ICheckinEntry } from '@/types/event-ops';
import { useToast } from '@/hooks/use-toast';
import { apiClient } from '@/lib/api/client';

export function CheckinEntry({
  entry,
  eventId,
  onWristbandSuccess,
  isConfirming,
}: {
  entry: ICheckinEntry;
  eventId: string;
  onWristbandSuccess: (ticketId: string) => void;
  isConfirming: Record<string, boolean>;
}) {
  const { toast } = useToast();
  const [isAnimating] = useState(true);

  const handleWristbandConfirm = async () => {
    if (isConfirming[entry.ticketId]) return; // debounce

    try {
      await apiClient.patch(
        `/admin/events/${eventId}/attendees/${entry.ticketId}/wristband`,
        { wristbandIssuedAt: new Date().toISOString() }
      );
      onWristbandSuccess(entry.ticketId);
    } catch (err) {
      toast('Failed to issue wristband. Try again.', 'error');
    }
  };

  const timeAgo = formatTimeAgo(new Date(entry.checkedInAt));

  return (
    <div
      className={`
        p-4 border-b border-muted flex gap-3 transition-all duration-500
        ${isAnimating ? 'bg-primary/10 opacity-100' : ''}
        hover:bg-muted/50
      `}
    >
      {/* Avatar */}
      <img
        src={entry.photoUrl || '/avatar-placeholder.png'}
        alt={entry.name}
        className="w-12 h-12 rounded-full object-cover flex-shrink-0"
      />

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <h4 className="font-semibold text-foreground text-lg truncate">
            {entry.name}
          </h4>
          {entry.source === 'posh' && (
            <span className="text-xs bg-secondary text-white px-2 py-1 rounded">
              Posh
            </span>
          )}
          {entry.source === 'walkin' && (
            <span className="text-xs bg-muted text-muted-foreground px-2 py-1 rounded">
              Walk-in
            </span>
          )}
        </div>
        {entry.specialty && (
          <p className="text-sm text-muted-foreground">{entry.specialty}</p>
        )}
        <p className="text-xs text-muted-foreground">{timeAgo}</p>
      </div>

      {/* Wristband button */}
      <button
        onClick={handleWristbandConfirm}
        disabled={isConfirming[entry.ticketId]}
        className={`
          flex-shrink-0 text-2xl transition-all
          ${
            entry.wristbandIssuedAt
              ? 'text-success cursor-default'
              : 'text-muted-foreground hover:text-foreground cursor-pointer'
          }
        `}
        title={entry.wristbandIssuedAt ? 'Wristband issued' : 'Tap to issue wristband'}
      >
        {entry.wristbandIssuedAt ? '✅' : '⬜'}
      </button>
    </div>
  );
}

function formatTimeAgo(date: Date): string {
  const now = new Date();
  const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return format(date, 'MMM d, h:mm a');
}
```

### Component: PoshExceptionQueue

```typescript
// components/event-ops/PoshExceptionQueue.tsx

import { useState } from 'react';
import { PoshException } from '@/types/event-ops';
import { useToast } from '@/hooks/use-toast';
import { apiClient } from '@/lib/api/client';
import { SearchUsersModal } from './SearchUsersModal';

export function PoshExceptionQueue({
  eventId,
  exceptions,
  onExceptionResolved,
}: {
  eventId: string;
  exceptions: PoshException[];
  onExceptionResolved: (poshOrderId: string) => void;
}) {
  const { toast } = useToast();
  const [selectedException, setSelectedException] = useState<PoshException | null>(null);
  const [isResolving, setIsResolving] = useState(false);

  const handleResolve = async (userId: string) => {
    if (!selectedException || isResolving) return;

    setIsResolving(true);
    try {
      await apiClient.patch(`/admin/posh-exceptions/${selectedException.id}/resolve`, {
        userId,
      });
      toast('Posh order matched successfully!', 'success');
      onExceptionResolved(selectedException.poshOrderId);
      setSelectedException(null);
    } catch (err: any) {
      toast(err.response?.data?.error || 'Failed to resolve exception', 'error');
    } finally {
      setIsResolving(false);
    }
  };

  if (exceptions.length === 0) {
    return (
      <div className="p-4 text-center text-muted-foreground">
        No Posh exceptions at this time
      </div>
    );
  }

  return (
    <>
      <div className="space-y-2 p-4">
        {exceptions.map((ex) => (
          <div
            key={ex.id}
            className="p-3 border border-warning/50 bg-warning/5 rounded-lg"
          >
            <div className="flex justify-between items-start gap-2">
              <div>
                <h4 className="font-semibold text-foreground">{ex.buyerName}</h4>
                <p className="text-sm text-muted-foreground">
                  Phone: •••• {ex.buyerPhone}
                </p>
                <p className="text-xs text-muted-foreground mt-1">{ex.ticketType}</p>
              </div>
              <button
                onClick={() => setSelectedException(ex)}
                className="px-3 py-1 text-sm bg-warning text-black rounded hover:bg-warning/90"
              >
                Resolve
              </button>
            </div>
          </div>
        ))}
      </div>

      {selectedException && (
        <SearchUsersModal
          isOpen={true}
          onClose={() => setSelectedException(null)}
          onSelect={handleResolve}
          isLoading={isResolving}
        />
      )}
    </>
  );
}
```

### Component: ActivationCodeCard

```typescript
// components/event-ops/ActivationCodeCard.tsx

import { useState } from 'react';
import { useToast } from '@/hooks/use-toast';

export function ActivationCodeCard({ code }: { code: string }) {
  const { toast } = useToast();
  const [isCopied, setIsCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setIsCopied(true);
      toast('Code copied!', 'success');
      setTimeout(() => setIsCopied(false), 2000);
    } catch (err) {
      toast('Failed to copy code', 'error');
    }
  };

  return (
    <div className="p-4 border border-primary/30 bg-primary/5 rounded-lg">
      <h3 className="text-sm text-muted-foreground mb-3 uppercase tracking-wide">
        Activation Code
      </h3>
      <div className="bg-card p-6 rounded mb-3 text-center">
        <code className="text-4xl font-mono font-bold text-primary tracking-widest">
          {code}
        </code>
      </div>
      <button
        onClick={handleCopy}
        className="w-full px-3 py-2 text-sm bg-primary hover:bg-primary-light text-primary-foreground rounded transition-colors"
      >
        {isCopied ? '✓ Copied' : 'Copy Code'}
      </button>
    </div>
  );
}
```

### Page: Event Selector

```typescript
// app/(dashboard)/events/ops/page.tsx

'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { useAuth } from '@/hooks/use-auth';
import { apiClient } from '@/lib/api/client';
import { Event } from '@/types/admin';
import { Skeleton } from '@/components/ui/skeleton';

export default function EventSelectorPage() {
  const router = useRouter();
  const { admin } = useAuth();
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchEvents() {
      try {
        const data = await apiClient.get('/admin/events?status=published');
        // Filter to active/upcoming (not completed/cancelled)
        const filtered = data.filter(
          (e: Event) => e.status === 'published' && new Date(e.endTime) > new Date()
        );
        setEvents(filtered);

        // Auto-select soonest upcoming if eventOps role and only one active
        if (admin?.role === 'eventOps' && filtered.length === 1) {
          router.push(`/events/ops/${filtered[0].id}`);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to load events');
      } finally {
        setIsLoading(false);
      }
    }

    fetchEvents();
  }, [admin, router]);

  if (isLoading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton key={i} className="h-24 w-full" />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 bg-destructive/10 text-destructive rounded-lg">
        {error}
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Select an Event</h1>

      {events.length === 0 ? (
        <div className="p-6 text-center text-muted-foreground bg-muted rounded-lg">
          No active events at this time
        </div>
      ) : (
        <div className="grid gap-4">
          {events.map((event) => (
            <button
              key={event.id}
              onClick={() => router.push(`/events/ops/${event.id}`)}
              className="p-4 border border-muted hover:border-primary hover:bg-muted transition-all text-left rounded-lg"
            >
              <h2 className="text-lg font-semibold text-foreground">{event.name}</h2>
              <p className="text-sm text-muted-foreground">
                {new Date(event.startTime).toLocaleString()}
              </p>
              <p className="text-xs text-muted-foreground mt-2">
                {event.venueName} • {event.capacity} capacity
              </p>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
```

### Page: Event Ops Main Screen

```typescript
// app/(dashboard)/events/ops/[eventId]/page.tsx

'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/hooks/use-auth';
import { useEventCheckins } from '@/hooks/use-event-checkins';
import { apiClient } from '@/lib/api/client';
import { Event } from '@/types/admin';
import { PoshException } from '@/types/event-ops';
import { CheckinFeed } from '@/components/event-ops/CheckinFeed';
import { EventOpsStats } from '@/components/event-ops/EventOpsStats';
import { PoshExceptionQueue } from '@/components/event-ops/PoshExceptionQueue';
import { ActivationCodeCard } from '@/components/event-ops/ActivationCodeCard';
import { EventOpsError } from '@/components/event-ops/EventOpsError';
import { Skeleton } from '@/components/ui/skeleton';
import { useToast } from '@/hooks/use-toast';

export default function EventOpsPage({ params }: { params: { eventId: string } }) {
  const { admin } = useAuth();
  const { toast } = useToast();
  const [event, setEvent] = useState<Event | null>(null);
  const [poshExceptions, setPoshExceptions] = useState<PoshException[]>([]);
  const [eventLoading, setEventLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'feed' | 'exceptions' | 'stats'>('feed');
  const [isMobile, setIsMobile] = useState(false);

  const {
    checkins,
    totalCount,
    isConnected,
    error: sseError,
  } = useEventCheckins({
    eventId: params.eventId,
    onError: (error) => toast(error, 'error'),
  });

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth < 640);
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    async function loadEvent() {
      try {
        const data = await apiClient.get(`/admin/events/${params.eventId}`);
        setEvent(data);
      } catch (err: any) {
        toast('Failed to load event', 'error');
      } finally {
        setEventLoading(false);
      }
    }

    async function loadPoshExceptions() {
      try {
        const data = await apiClient.get(
          `/admin/posh-exceptions?eventId=${params.eventId}`
        );
        setPoshExceptions(data);
      } catch (err) {
        // Silent fail for exceptions; not critical
      }
    }

    loadEvent();
    loadPoshExceptions();
  }, [params.eventId, toast]);

  const handleWristbandSuccess = (ticketId: string) => {
    toast('Wristband issued! Push notification sent.', 'success');
  };

  const handleExceptionResolved = (poshOrderId: string) => {
    setPoshExceptions((prev) =>
      prev.filter((ex) => ex.poshOrderId !== poshOrderId)
    );
  };

  if (eventLoading) {
    return <Skeleton className="h-screen w-full" />;
  }

  if (!event) {
    return (
      <div className="p-6 text-center text-destructive">
        Event not found
      </div>
    );
  }

  // Mobile view: tabbed layout
  if (isMobile) {
    return (
      <div className="flex flex-col h-screen bg-background">
        {sseError && <EventOpsError message={sseError} />}

        {/* Header */}
        <div className="p-4 border-b border-muted">
          <h1 className="text-xl font-bold text-foreground">{event.name}</h1>
          <p className="text-xs text-muted-foreground">
            {new Date(event.startTime).toLocaleString()} • Check-ins: {totalCount}
          </p>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-hidden">
          {activeTab === 'feed' && (
            <CheckinFeed
              checkins={checkins}
              eventId={params.eventId}
              onWristbandSuccess={handleWristbandSuccess}
            />
          )}
          {activeTab === 'exceptions' && (
            <PoshExceptionQueue
              eventId={params.eventId}
              exceptions={poshExceptions}
              onExceptionResolved={handleExceptionResolved}
            />
          )}
          {activeTab === 'stats' && (
            <div className="p-4 space-y-4 overflow-y-auto h-full">
              <EventOpsStats checkins={checkins} />
              {event.activation_code && (
                <ActivationCodeCard code={event.activation_code} />
              )}
            </div>
          )}
        </div>

        {/* Tab bar */}
        <div className="flex border-t border-muted">
          {(['feed', 'exceptions', 'stats'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-3 text-center text-sm font-medium transition-colors ${
                activeTab === tab
                  ? 'border-b-2 border-primary text-primary'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {tab === 'feed' && 'Live Feed'}
              {tab === 'exceptions' && `Exceptions (${poshExceptions.length})`}
              {tab === 'stats' && 'Stats'}
            </button>
          ))}
        </div>
      </div>
    );
  }

  // Desktop view: two-column layout
  return (
    <div className="flex gap-6 h-screen overflow-hidden bg-background">
      {sseError && <EventOpsError message={sseError} />}

      {/* Left column: Live feed */}
      <div className="flex-1 flex flex-col border-r border-muted overflow-hidden">
        <div className="p-4 border-b border-muted">
          <h1 className="text-2xl font-bold text-foreground">{event.name}</h1>
          <p className="text-sm text-muted-foreground">
            {new Date(event.startTime).toLocaleString()} • Check-ins: {totalCount}
          </p>
        </div>
        <CheckinFeed
          checkins={checkins}
          eventId={params.eventId}
          onWristbandSuccess={handleWristbandSuccess}
          className="flex-1 overflow-y-auto"
        />
      </div>

      {/* Right column: Stats + Exceptions */}
      <div className="w-80 flex flex-col border-l border-muted overflow-hidden">
        <div className="flex-1 overflow-y-auto p-4 space-y-6">
          <EventOpsStats checkins={checkins} />

          {poshExceptions.length > 0 && (
            <div>
              <h3 className="text-sm font-semibold text-foreground mb-3 uppercase">
                Posh Exceptions ({poshExceptions.length})
              </h3>
              <PoshExceptionQueue
                eventId={params.eventId}
                exceptions={poshExceptions}
                onExceptionResolved={handleExceptionResolved}
              />
            </div>
          )}

          {event.activation_code && (
            <ActivationCodeCard code={event.activation_code} />
          )}
        </div>
      </div>
    </div>
  );
}
```

### Responsive Layout Component

```typescript
// components/event-ops/EventOpsLayout.tsx

import { ReactNode } from 'react';
import { useMediaQuery } from '@/hooks/use-media-query';

export function EventOpsLayout({
  header,
  leftColumn,
  rightColumn,
  mobileTab,
}: {
  header: ReactNode;
  leftColumn: ReactNode;
  rightColumn: ReactNode;
  mobileTab?: 'feed' | 'exceptions' | 'stats';
}) {
  const isMobile = !useMediaQuery('(min-width: 768px)');

  if (isMobile) {
    return (
      <div className="flex flex-col h-screen">
        <div className="border-b border-muted">{header}</div>
        <div className="flex-1 overflow-hidden">
          {mobileTab === 'feed' && leftColumn}
          {mobileTab === 'exceptions' && rightColumn}
        </div>
      </div>
    );
  }

  return (
    <div className="flex gap-6 h-screen overflow-hidden">
      <div className="flex-1 flex flex-col border-r border-muted overflow-hidden">
        <div className="border-b border-muted">{header}</div>
        <div className="flex-1 overflow-y-auto">{leftColumn}</div>
      </div>
      <div className="w-80 flex flex-col overflow-hidden border-l border-muted p-4">
        <div className="flex-1 overflow-y-auto space-y-6">{rightColumn}</div>
      </div>
    </div>
  );
}
```

---

## Test Suite

### Unit Tests (Vitest)

```typescript
// packages/react-admin/__tests__/hooks/use-event-checkins.test.ts

import { renderHook, waitFor } from '@testing-library/react';
import { useEventCheckins } from '@/hooks/use-event-checkins';

describe('useEventCheckins', () => {
  it('receives checkin events from SSE stream', async () => {
    const mockEventSource = {
      addEventListener: vi.fn(),
      close: vi.fn(),
    };

    global.EventSource = vi.fn(() => mockEventSource) as any;

    const { result } = renderHook(() =>
      useEventCheckins({ eventId: 'evt-123' })
    );

    const checkinListener = mockEventSource.addEventListener.mock.calls[0][1];
    checkinListener({
      data: JSON.stringify({
        ticketId: 'ticket-1',
        name: 'Alice',
        checkedInAt: new Date().toISOString(),
      }),
    });

    await waitFor(() => {
      expect(result.current.checkins).toHaveLength(1);
      expect(result.current.checkins[0].name).toBe('Alice');
    });
  });

  it('auto-reconnects on disconnect with exponential backoff', async () => {
    const mockEventSource = {
      addEventListener: vi.fn(),
      close: vi.fn(),
    };

    global.EventSource = vi.fn(() => mockEventSource) as any;

    renderHook(() => useEventCheckins({ eventId: 'evt-123' }));

    const errorListener = mockEventSource.addEventListener.mock.calls.find(
      (call) => call[0] === 'error'
    )?.[1];

    if (errorListener) {
      errorListener({});
      await waitFor(() => {
        expect(global.EventSource).toHaveBeenCalledTimes(2);
      }, { timeout: 2000 });
    }
  });

  it('updates wristband status on wristband event', async () => {
    const mockEventSource = {
      addEventListener: vi.fn(),
      close: vi.fn(),
    };

    global.EventSource = vi.fn(() => mockEventSource) as any;

    const { result } = renderHook(() =>
      useEventCheckins({ eventId: 'evt-123' })
    );

    // Add checkin first
    const checkinListener = mockEventSource.addEventListener.mock.calls.find(
      (call) => call[0] === 'checkin'
    )?.[1];
    checkinListener?.({
      data: JSON.stringify({
        ticketId: 'ticket-1',
        name: 'Alice',
        wristbandIssuedAt: null,
      }),
    });

    // Issue wristband
    const wristbandListener = mockEventSource.addEventListener.mock.calls.find(
      (call) => call[0] === 'wristband'
    )?.[1];
    wristbandListener?.({
      data: JSON.stringify({
        ticketId: 'ticket-1',
        wristbandIssuedAt: new Date().toISOString(),
      }),
    });

    await waitFor(() => {
      expect(result.current.checkins[0].wristbandIssuedAt).toBeDefined();
    });
  });
});
```

```typescript
// packages/react-admin/__tests__/components/CheckinEntry.test.tsx

import { render, screen, fireEvent } from '@testing-library/react';
import { CheckinEntry } from '@/components/event-ops/CheckinEntry';

describe('CheckinEntry', () => {
  const mockEntry = {
    ticketId: 'ticket-1',
    name: 'Alice Smith',
    specialty: 'Photographer',
    checkedInAt: new Date(Date.now() - 2 * 60000).toISOString(), // 2m ago
    source: 'walkin' as const,
    poshOrderId: undefined,
    wristbandIssuedAt: null,
  };

  it('renders entry with name, specialty, and time', () => {
    render(
      <CheckinEntry
        entry={mockEntry}
        eventId="evt-123"
        onWristbandSuccess={() => {}}
        isConfirming={{}}
      />
    );

    expect(screen.getByText('Alice Smith')).toBeInTheDocument();
    expect(screen.getByText('Photographer')).toBeInTheDocument();
    expect(screen.getByText('2m ago')).toBeInTheDocument();
  });

  it('shows pending wristband icon (⬜) when not issued', () => {
    render(
      <CheckinEntry
        entry={mockEntry}
        eventId="evt-123"
        onWristbandSuccess={() => {}}
        isConfirming={{}}
      />
    );

    const icon = screen.getByText('⬜');
    expect(icon).toBeInTheDocument();
  });

  it('shows issued wristband icon (✅) when issued', () => {
    const issuedEntry = {
      ...mockEntry,
      wristbandIssuedAt: new Date().toISOString(),
    };

    render(
      <CheckinEntry
        entry={issuedEntry}
        eventId="evt-123"
        onWristbandSuccess={() => {}}
        isConfirming={{}}
      />
    );

    expect(screen.getByText('✅')).toBeInTheDocument();
  });

  it('calls wristband confirm handler on tap', async () => {
    const onSuccess = vi.fn();

    render(
      <CheckinEntry
        entry={mockEntry}
        eventId="evt-123"
        onWristbandSuccess={onSuccess}
        isConfirming={{}}
      />
    );

    const button = screen.getByRole('button', { name: /tap to issue/i });
    fireEvent.click(button);

    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalledWith('ticket-1');
    });
  });
});
```

### End-to-End Tests (Playwright)

```typescript
// packages/react-admin/e2e/event-ops.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Event Ops Screen', () => {
  test('eventOps login → sees Event Ops screen, not dashboard', async ({
    page,
  }) => {
    await page.goto('/login');
    await page.fill('[name=email]', 'eventops@industrynight.test');
    await page.fill('[name=password]', 'test-password');
    await page.click('button[type=submit]');

    await expect(page).toHaveURL('/');
    // Dashboard should NOT be visible; Event Ops should be in sidebar
    await expect(page.locator('[data-testid=sidebar-event-ops]')).toBeVisible();
  });

  test('event selector lists active events and navigates on selection', async ({
    page,
  }) => {
    await page.goto('/events/ops');
    await expect(page.locator('h1')).toContainText('Select an Event');

    const eventCard = page.locator('[data-testid=event-card]').first();
    await eventCard.click();

    // Should navigate to /events/ops/[eventId]
    await expect(page).toHaveURL(/\/events\/ops\/[a-z0-9-]+/);
  });

  test('SSE stream receives check-ins and updates feed', async ({ page }) => {
    // Mock SSE endpoint to push a check-in
    await page.routeFromHAR('network.har', {
      notFound: 'abort',
    });

    await page.goto('/events/ops/evt-test-123');

    // Simulate SSE check-in event
    await page.evaluate(() => {
      const event = new MessageEvent('checkin', {
        data: JSON.stringify({
          ticketId: 'ticket-1',
          name: 'Alice',
          specialty: 'Photographer',
          checkedInAt: new Date().toISOString(),
          source: 'walkin',
          wristbandIssuedAt: null,
        }),
      });
      window.dispatchEvent(event);
    });

    // Check-in should appear in feed
    await expect(page.locator('text=Alice')).toBeVisible({ timeout: 1000 });
  });

  test('wristband confirm: tap icon → calls PATCH → toast shows success', async ({
    page,
  }) => {
    await page.goto('/events/ops/evt-test-123');

    // Intercept PATCH request
    let patchCalled = false;
    await page.route('**/api/admin/events/**/attendees/**/wristband', (route) => {
      patchCalled = true;
      route.abort();
    });

    // Tap wristband icon (the ⬜ button)
    const wristbandButton = page.locator('[title="Tap to issue wristband"]').first();
    await wristbandButton.click();

    // Verify PATCH was called
    await expect(async () => {
      expect(patchCalled).toBe(true);
    }).toPass({ timeout: 2000 });
  });

  test('activation code displays and can be copied', async ({ page }) => {
    await page.goto('/events/ops/evt-test-123');

    // Find activation code
    const codeElement = page.locator('code').first();
    await expect(codeElement).toBeVisible();

    // Copy button
    const copyButton = page.locator('button:has-text("Copy Code")');
    await copyButton.click();

    // Toast should show
    await expect(page.locator('text=Code copied')).toBeVisible();
  });

  test('mobile view: tabs work correctly', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });

    await page.goto('/events/ops/evt-test-123');

    // Tabs should be visible
    const tabs = page.locator('[role=tab]');
    await expect(tabs.nth(0)).toContainText('Live Feed');
    await expect(tabs.nth(1)).toContainText('Exceptions');
    await expect(tabs.nth(2)).toContainText('Stats');

    // Click Stats tab
    await tabs.nth(2).click();

    // Activation code should be visible
    await expect(page.locator('text=Activation Code')).toBeVisible();

    // Click Exceptions tab
    await tabs.nth(1).click();

    // Posh exception queue should be visible
    await expect(
      page.locator('text=Posh exceptions at this time')
    ).toBeVisible();
  });

  test('Posh exception resolve: search user, select, calls API', async ({
    page,
  }) => {
    await page.goto('/events/ops/evt-test-123');

    // Click Resolve button
    const resolveButton = page.locator('button:has-text("Resolve")').first();
    await resolveButton.click();

    // Modal should open
    await expect(page.locator('text=Search Users')).toBeVisible();

    // Type in search
    await page.fill('[placeholder*=search]', 'alice', { force: true });

    // Select a user
    const userOption = page.locator('[role=option]').first();
    await userOption.click();

    // Exception should disappear (optimistically)
    await expect(
      page.locator('text=Posh exceptions at this time')
    ).toBeVisible();
  });
});
```

---

## Definition of Done

- [ ] `/events/ops/` event selector route renders correctly
- [ ] `/events/ops/[eventId]` main Event Ops screen renders
- [ ] SSE hook (`useEventCheckins`) connects and receives check-in events
- [ ] Check-in feed displays attendees with avatar, name, specialty, time, badges
- [ ] Wristband confirm button (⬜→✅): tap → PATCH call → FCM notification
- [ ] Wristband confirm debounced (no double-tap within 2s per ticket)
- [ ] Stats cards (Total, Wristbands Issued, Posh, Walk-in) auto-update from checkins
- [ ] Posh exception queue shows unmatched orders; "Resolve" → modal with user search
- [ ] Resolving Posh exception: PATCH API call → exception removed from list (optimistic)
- [ ] Activation code displays in large monospace font; copy-to-clipboard works
- [ ] Mobile responsive: tablets (landscape) → two-column; phones (portrait) → tabbed
- [ ] Dark theme applied (from B0 design system)
- [ ] Error handling: SSE disconnect banner, toast notifications for failures
- [ ] Auto-reconnect on SSE disconnect (exponential backoff tested)
- [ ] Unit tests pass: `npm test` for hook + components
- [ ] E2E tests pass (Playwright): SSE stream, wristband confirm, Posh resolve, mobile tabs
- [ ] No TypeScript strict mode errors (`npm run type-check`)
- [ ] No console errors or warnings during normal operation
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/B2-event-ops-screen`
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

### What B3 (or future screens) should know about this implementation
-

---

## Interrogative Session

**Agent Questions (for Claude Code execution):**

**Q1: SSE connection strategy — should the EventSource URL include the JWT token as a query parameter, or should we rely on the Next.js API proxy to inject it? What's the security trade-off?**
> Jeff:

**Q2: The wristband confirm is optimistic (update UI immediately, then call API). If the PATCH fails, we revert. But what if the user taps multiple times in quick succession? The debounce at 2 seconds per ticket is coarse — should we use a more granular state machine or a different approach?**
> Jeff:

**Q3: On mobile, should the stats cards be displayed as a smaller set (just Total & Wristbands Issued) to save space, or always show all four? And should the activation code be accessible from all three tabs or only the Stats tab?**
> Jeff:

**Jeff Questions (for project owner):**

**Q1: Is the 5-second polling interval on the backend suitable for venue-scale loads (100-500 attendees checking in over 2-3 hours)? Or should we investigate WebSocket for true push from API to client?**
> Agent:

**Q2: The Posh exception "Resolve" modal searches users by name/phone. Should we also allow search by email, or is phone + name sufficient for venue staff to identify the buyer?**
> Agent:

**Q3: Post-implementation, should we add a "Refresh" button on the connection error banner, or let auto-reconnect handle it silently? What's the UX preference?**
> Agent:

**Ready for review:** ☐ Yes
