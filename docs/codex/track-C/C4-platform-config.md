# [Track-C4] Platform Config + API Key Status

**Track:** C (Backend + Schema)
**Sequence:** 4 of 5 in Track C
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4-mini ← tight-spec, low-ambiguity prompt; fast-path eligible
**A/B Test:** No
**Estimated Effort:** Small (2-3 hours)
**Dependencies:** C0 (platform_config table created), C2 (FCM + LLM services), C3 (Admin React routes)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


### C0 Winner Handoff (Control Session)

- Winner for C0 execution/apply authority: `claude-sonnet-4-6` (control session decision).
- Source-of-truth migration: `packages/database/migrations/004_phase0_foundation.sql`.
- Assume these C0 outputs exist before implementing C4:
  - `platform_config` table exists with seeded keys
  - `llm_usage_log` exists for operational call telemetry
  - `admin_role` includes `moderator` and `eventOps`
- C4 must not change C0 directly. If C4 needs schema updates, add a new migration file.

---

## Context

Read these before implementing:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — full project reference, API section (routes, middleware, services)
- `packages/api/src/routes/admin.ts` — existing admin endpoints pattern
- `packages/api/src/middleware/` — authentication and validation patterns
- `packages/api/src/__tests__/customers.test.ts` — Jest test pattern for admin endpoints
- `packages/api/src/services/` — service layer patterns (sms.ts, storage.ts)
- `packages/database/migrations/004_phase0_foundation.sql` (from C0) — platform_config table schema
- `packages/react-admin/app` — page structure and auth gating

---

## Goal

Expose the `platform_config` table through admin API endpoints, and add a service health/config status endpoint that shows which optional services (Twilio, S3, FCM, Anthropic, SES) are currently configured. This gives admins visibility into platform operational state without exposing credentials.

---

## Acceptance Criteria

- [ ] `GET /admin/platform-config` returns all non-secret config rows sorted alphabetically
- [ ] `GET /admin/platform-config` filters out rows where key contains `secret`, `key`, `token`, or `password`
- [ ] `PATCH /admin/platform-config/:key` updates value, creates audit log entry, returns updated row
- [ ] `PATCH /admin/platform-config/:key` with non-existent key returns 404 (no upsert)
- [ ] `POST /admin/platform-config/reset/:key` resets config to default value from `PLATFORM_CONFIG_DEFAULTS`
- [ ] `GET /admin/system-status` returns JSON with service configuration status (no secrets exposed)
- [ ] System status endpoint checks: twilio (mode: verify|sms), s3 (bucket name), ses, fcm, anthropic, database (connectivity)
- [ ] All three endpoints require `authenticateAdmin` + `requirePlatformAdmin` middleware
- [ ] Audit log entry created for every config update (action: 'update', entity: 'platform_config', entityId: key)
- [ ] React admin Settings page exists at `app/(protected)/settings/page.tsx`
- [ ] Platform Config tab renders table with inline edit + reset buttons per row
- [ ] Feature flag rows (feature.*) render as toggle switches (value "true"/"false" ↔ boolean)
- [ ] System Status tab shows service cards with green check / red X, "Refresh" button
- [ ] S3 card displays bucket name (not a secret)
- [ ] Twilio card displays mode (verify vs sms)
- [ ] Only platformAdmin can access Settings page (permissions.ts gating)
- [ ] Jest test suite covers: config CRUD, non-existent key handling, default reset, audit logging
- [ ] Jest test suite covers: system status with all env vars set, with none set, database unreachable handling
- [ ] All tests pass without modifying existing test files (new files only: `platform-config.test.ts`, `system-status.test.ts`)

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin, I open Settings → Platform Config and see all current config values, can edit them inline, and save without redeploying | PATCH updates value + audits change |
| Platform Admin | As a platform admin setting up a new environment, I open Settings → System Status and immediately see which services are missing credentials (Twilio, S3, SES, FCM, Anthropic) | GET /admin/system-status does NOT expose secrets, only boolean configured status |
| Platform Admin | As a platform admin, I change the LLM moderation confidence threshold and then realize I made a mistake — I click Reset to restore the default value | POST /admin/platform-config/reset/:key restores from hardcoded defaults |
| System (Feature Flag) | As a feature flag consumer (jobs board feature), I can read `feature.jobs_board` from platform_config to enable/disable the feature without code deploy | D track consumes this config |
| System (Audit) | As the audit log, I record every platform_config change with who changed it and when | Every PATCH creates an audit_log row (action: 'update', entity: 'platform_config') |

---

## Technical Spec

### 1. Backend — API Endpoints (packages/api/src/routes/admin.ts)

#### A. Platform Config Defaults (new const or lib/platform-config.ts)

```typescript
export const PLATFORM_CONFIG_DEFAULTS: Record<string, { value: string; description: string }> = {
  'llm.moderation.model':           { value: 'claude-haiku-4-5', description: 'Model used for post moderation' },
  'llm.moderation.confidence_threshold': { value: '0.85', description: 'Minimum confidence score to auto-remove content' },
  'llm.image_tagging.model':        { value: 'claude-haiku-4-5', description: 'Model used for image tagging' },
  'llm.event_wrap.model':           { value: 'claude-sonnet-4-6', description: 'Model used for event wrap reports' },
  'feature.push_notifications':     { value: 'true', description: 'Enable FCM push notifications' },
  'feature.jobs_board':             { value: 'false', description: 'Enable jobs board feature' },
  'feature.community_feed':         { value: 'true', description: 'Enable community feed' },
  'analytics.influence.min_connections': { value: '3', description: 'Minimum connections to appear in influence rankings' },
};
```

#### B. GET /admin/platform-config

- Auth: `authenticateAdmin` + `requirePlatformAdmin`
- Query params: none
- Returns: Array of all platform_config rows as JSON
  ```json
  [
    { "key": "analytics.influence.min_connections", "value": "3", "description": "Minimum connections to appear in influence rankings", "updatedAt": "2026-03-22T15:30:00Z", "updatedByAdminId": "uuid..." },
    { "key": "feature.community_feed", "value": "true", "description": "Enable community feed", "updatedAt": "2026-01-10T12:00:00Z", "updatedByAdminId": null },
    ...
  ]
  ```
- Logic:
  - Query: `SELECT key, value, description, updated_at, updated_by_admin_id FROM platform_config WHERE key NOT IN (list of secret keys) ORDER BY key ASC`
  - Secret filter: exclude rows where key ILIKE any of: '%secret%', '%key%', '%token%', '%password%'
  - Sorted alphabetically by key
  - Do NOT fail if rows exist with secret keys (they shouldn't be in platform_config, but handle gracefully)

#### C. PATCH /admin/platform-config/:key

- Auth: `authenticateAdmin` + `requirePlatformAdmin`
- Params: `key` (string)
- Body: `{ value: string }`
- Returns: Updated row (same shape as GET)
- Status codes:
  - 200 OK: successfully updated
  - 404 Not Found: key does not exist in platform_config table
  - 400 Bad Request: value is empty or invalid (validation per spec below)
- Logic:
  - Validate: key must exist in table (no upsert — prevent typos from creating garbage config entries)
  - UPDATE: `UPDATE platform_config SET value = $1, updated_at = NOW(), updated_by_admin_id = $2 WHERE key = $3 RETURNING *`
  - Query admin user ID from JWT (req.user.adminId or req.admin.id — check existing pattern in admin auth middleware)
  - Validation: `value` string must be non-empty; strip whitespace
  - Audit log: after successful update, call auditLog('update', 'platform_config', key, null, { oldValue: ..., newValue: ... })
  - Return the updated row

#### D. POST /admin/platform-config/reset/:key

- Auth: `authenticateAdmin` + `requirePlatformAdmin`
- Params: `key` (string)
- Body: none
- Returns: Reset row (same shape as GET)
- Status codes:
  - 200 OK: successfully reset
  - 404 Not Found: key not recognized in PLATFORM_CONFIG_DEFAULTS
- Logic:
  - Validate: key must exist in PLATFORM_CONFIG_DEFAULTS
  - Fetch current row to get old value for audit log
  - UPDATE: `UPDATE platform_config SET value = $1, updated_at = NOW(), updated_by_admin_id = $2 WHERE key = $3 RETURNING *`
  - Use default value from PLATFORM_CONFIG_DEFAULTS[key].value
  - Audit log: log as 'update' with oldValue and newValue set to defaults
  - Return the reset row

#### E. GET /admin/system-status

- Auth: `authenticateAdmin` + `requirePlatformAdmin`
- Query params: none
- Returns: JSON object with service configuration status
  ```json
  {
    "services": {
      "twilio": { "configured": true, "mode": "verify" },
      "s3": { "configured": true, "bucket": "industrynight-assets-prod" },
      "ses": { "configured": true },
      "fcm": { "configured": false },
      "anthropic": { "configured": true },
      "database": { "connected": true, "poolSize": 10 }
    },
    "environment": "production",
    "version": "1.0.0",
    "nodeVersion": "20.11.0"
  }
  ```
- Logic:
  - **twilio:**
    - `configured: !!process.env.TWILIO_ACCOUNT_SID && !!process.env.TWILIO_AUTH_TOKEN`
    - `mode: process.env.TWILIO_VERIFY_SERVICE_SID ? 'verify' : 'sms'` (if configured)
  - **s3:**
    - `configured: !!process.env.S3_BUCKET`
    - `bucket: process.env.S3_BUCKET` (safe to show — not a secret)
  - **ses:**
    - `configured: !!process.env.SES_FROM_EMAIL`
  - **fcm:**
    - `configured: await fcmAvailable()` (import from services/fcm.ts, should be an exported boolean or async function)
  - **anthropic:**
    - `configured: !!process.env.ANTHROPIC_API_KEY`
  - **database:**
    - Query: `SELECT 1` (fast connectivity check)
    - `connected: true` if query succeeds, `false` if error (do NOT crash endpoint; catch exception and return connected: false)
    - `poolSize: pool.totalCount || 10` (approximate from pg Pool or hardcoded default)
  - **environment:** process.env.NODE_ENV (production | development)
  - **version:** read from package.json via `require('../../../package.json').version`
  - **nodeVersion:** process.version (e.g., "v20.11.0")
- Error handling: If any service check throws, catch it and set that service to configured: false / connected: false. Do NOT crash the endpoint.

### 2. Backend — Service Layer (new file: packages/api/src/lib/platform-config.ts)

Export the `PLATFORM_CONFIG_DEFAULTS` constant so it's reusable across routes and tests.

### 3. Backend — Tests (packages/api/src/__tests__)

#### A. New file: platform-config.test.ts

```typescript
// packages/api/src/__tests__/platform-config.test.ts
import request from 'supertest';
import app from '../app';
import { createAdminWithToken, db } from './test-utils'; // adjust import based on existing test setup

describe('GET /admin/platform-config', () => {
  it('returns all config rows except those with secret/key/token/password in key', async () => {
    // Seed: insert a config row with 'secret' in the key to verify filtering
    await db.query(`
      INSERT INTO platform_config (key, value, description)
      VALUES ('test_secret_key', '{"hidden": true}', 'This should be filtered')
      ON CONFLICT DO NOTHING
    `);

    const { token, adminId } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/platform-config')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Verify secret key is not in response
    const keys = res.body.map((row: any) => row.key);
    expect(keys).not.toContain('test_secret_key');
    // Verify legitimate keys are present
    expect(keys).toContain('llm.moderation.model');
  });

  it('returns rows sorted alphabetically by key', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/platform-config')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    const keys = res.body.map((row: any) => row.key);
    const sortedKeys = [...keys].sort();
    expect(keys).toEqual(sortedKeys);
  });

  it('requires platformAdmin role', async () => {
    // Create a non-admin user or admin with different role
    const { token: nonAdminToken } = await createAdminWithToken({ role: 'moderator' });
    const res = await request(app)
      .get('/admin/platform-config')
      .set('Authorization', `Bearer ${nonAdminToken}`);

    expect(res.status).toBe(403);
  });
});

describe('PATCH /admin/platform-config/:key', () => {
  it('updates config value and returns updated row', async () => {
    const { token, adminId } = await createAdminWithToken();
    const res = await request(app)
      .patch('/admin/platform-config/llm.moderation.confidence_threshold')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: '0.95' });

    expect(res.status).toBe(200);
    expect(res.body.key).toBe('llm.moderation.confidence_threshold');
    expect(res.body.value).toBe('0.95');
    expect(res.body.updatedByAdminId).toBe(adminId);
  });

  it('returns 404 for non-existent key', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .patch('/admin/platform-config/nonexistent.key')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'test' });

    expect(res.status).toBe(404);
  });

  it('creates an audit log entry on update', async () => {
    const { token, adminId } = await createAdminWithToken();
    const res = await request(app)
      .patch('/admin/platform-config/feature.jobs_board')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'true' });

    expect(res.status).toBe(200);

    // Verify audit log entry
    const auditRes = await db.query(`
      SELECT * FROM audit_log
      WHERE entity = 'platform_config' AND entity_id = 'feature.jobs_board' AND action = 'update'
      ORDER BY created_at DESC LIMIT 1
    `);
    expect(auditRes.rows.length).toBeGreaterThan(0);
    expect(auditRes.rows[0].admin_id).toBe(adminId);
  });

  it('rejects empty value', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .patch('/admin/platform-config/llm.moderation.model')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: '' });

    expect(res.status).toBe(400);
  });
});

describe('POST /admin/platform-config/reset/:key', () => {
  it('resets config to default value', async () => {
    const { token } = await createAdminWithToken();

    // First, change the value
    await request(app)
      .patch('/admin/platform-config/feature.community_feed')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'false' });

    // Then reset it
    const res = await request(app)
      .post('/admin/platform-config/reset/feature.community_feed')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.value).toBe('true'); // default from PLATFORM_CONFIG_DEFAULTS
  });

  it('returns 404 for unrecognized key', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .post('/admin/platform-config/reset/unknown.config.key')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('creates audit log entry on reset', async () => {
    const { token, adminId } = await createAdminWithToken();
    const res = await request(app)
      .post('/admin/platform-config/reset/llm.moderation.model')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);

    const auditRes = await db.query(`
      SELECT * FROM audit_log
      WHERE entity = 'platform_config' AND entity_id = 'llm.moderation.model'
      ORDER BY created_at DESC LIMIT 1
    `);
    expect(auditRes.rows.length).toBeGreaterThan(0);
  });
});
```

#### B. New file: system-status.test.ts

```typescript
// packages/api/src/__tests__/system-status.test.ts
import request from 'supertest';
import app from '../app';
import { createAdminWithToken, db } from './test-utils';

describe('GET /admin/system-status', () => {
  it('returns service status object with all required fields', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.services).toBeDefined();
    expect(res.body.services.twilio).toBeDefined();
    expect(res.body.services.s3).toBeDefined();
    expect(res.body.services.ses).toBeDefined();
    expect(res.body.services.fcm).toBeDefined();
    expect(res.body.services.anthropic).toBeDefined();
    expect(res.body.services.database).toBeDefined();
    expect(res.body.environment).toBeDefined();
    expect(res.body.version).toBeDefined();
    expect(res.body.nodeVersion).toBeDefined();
  });

  it('shows database as connected when DB is reachable', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.services.database.connected).toBe(true);
  });

  it('shows services as configured based on environment variables', async () => {
    // This test assumes TWILIO and S3 are configured in test env
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    // Behavior depends on test environment setup
    // Just verify the structure is correct
    expect(typeof res.body.services.twilio.configured).toBe('boolean');
    expect(typeof res.body.services.s3.configured).toBe('boolean');
  });

  it('never exposes secret values (API keys, credentials)', async () => {
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    const jsonString = JSON.stringify(res.body);
    // Verify no actual keys/tokens in response (basic check)
    expect(jsonString).not.toContain(process.env.TWILIO_AUTH_TOKEN || 'TWILIO_AUTH_TOKEN_NOT_SET');
    expect(jsonString).not.toContain(process.env.AWS_SECRET_ACCESS_KEY || 'AWS_SECRET_NOT_SET');
  });

  it('handles database connectivity failure gracefully', async () => {
    // This is a complex test; if it's too difficult to mock DB failure, skip it
    // The important thing is that the endpoint doesn't crash
    const { token } = await createAdminWithToken();
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${token}`);

    // Should not throw 500
    expect(res.status).not.toBe(500);
  });

  it('requires platformAdmin role', async () => {
    const { token: moderatorToken } = await createAdminWithToken({ role: 'moderator' });
    const res = await request(app)
      .get('/admin/system-status')
      .set('Authorization', `Bearer ${moderatorToken}`);

    expect(res.status).toBe(403);
  });
});
```

### 4. Frontend — React Admin Settings Page (packages/react-admin)

#### A. New file: app/(protected)/settings/page.tsx

```typescript
// packages/react-admin/app/(protected)/settings/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { PlatformConfigTable } from './_components/platform-config-table';
import { SystemStatusCards } from './_components/system-status-cards';

export default function SettingsPage() {
  // Permissions are enforced by layout.tsx (requirePlatformAdmin)
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Settings</h1>
        <p className="text-muted-foreground mt-2">Manage platform configuration and service status</p>
      </div>

      <Tabs defaultValue="config" className="w-full">
        <TabsList>
          <TabsTrigger value="config">Platform Config</TabsTrigger>
          <TabsTrigger value="status">System Status</TabsTrigger>
        </TabsList>

        <TabsContent value="config" className="space-y-4">
          <PlatformConfigTable />
        </TabsContent>

        <TabsContent value="status" className="space-y-4">
          <SystemStatusCards />
        </TabsContent>
      </Tabs>
    </div>
  );
}
```

#### B. New component: _components/platform-config-table.tsx

```typescript
// packages/react-admin/app/(protected)/settings/_components/platform-config-table.tsx
'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { useAdminApi } from '@/hooks/useAdminApi';
import { useToast } from '@/hooks/useToast';

interface ConfigRow {
  key: string;
  value: string;
  description: string;
  updatedAt: string;
  updatedByAdminId: string | null;
}

export function PlatformConfigTable() {
  const [config, setConfig] = useState<ConfigRow[]>([]);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');
  const [loading, setLoading] = useState(true);
  const { adminApi } = useAdminApi();
  const { toast } = useToast();

  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    try {
      setLoading(true);
      const data = await adminApi.getPlatformConfig();
      setConfig(data);
    } catch (error) {
      toast({ title: 'Error loading config', description: String(error), variant: 'destructive' });
    } finally {
      setLoading(false);
    }
  };

  const isFeatureFlag = (key: string) => key.startsWith('feature.');

  const handleEdit = (row: ConfigRow) => {
    setEditingKey(row.key);
    setEditValue(row.value);
  };

  const handleSave = async (key: string) => {
    try {
      await adminApi.updatePlatformConfig(key, editValue);
      toast({ title: 'Config updated' });
      setEditingKey(null);
      await loadConfig();
    } catch (error) {
      toast({ title: 'Error updating config', description: String(error), variant: 'destructive' });
    }
  };

  const handleReset = async (key: string) => {
    try {
      await adminApi.resetPlatformConfig(key);
      toast({ title: 'Config reset to default' });
      await loadConfig();
    } catch (error) {
      toast({ title: 'Error resetting config', description: String(error), variant: 'destructive' });
    }
  };

  const handleToggle = async (key: string, newValue: boolean) => {
    try {
      await adminApi.updatePlatformConfig(key, String(newValue));
      toast({ title: 'Feature flag updated' });
      await loadConfig();
    } catch (error) {
      toast({ title: 'Error updating feature flag', description: String(error), variant: 'destructive' });
    }
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div className="rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Key</TableHead>
            <TableHead>Value</TableHead>
            <TableHead>Description</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {config.map((row) => (
            <TableRow key={row.key}>
              <TableCell className="font-mono text-sm">{row.key}</TableCell>
              <TableCell>
                {editingKey === row.key ? (
                  isFeatureFlag(row.key) ? (
                    <Switch
                      checked={editValue === 'true'}
                      onCheckedChange={(checked) =>
                        handleToggle(row.key, checked)
                      }
                    />
                  ) : (
                    <Input
                      value={editValue}
                      onChange={(e) => setEditValue(e.target.value)}
                      className="w-64"
                    />
                  )
                ) : isFeatureFlag(row.key) ? (
                  <span className="px-2 py-1 rounded bg-gray-100">
                    {row.value === 'true' ? 'Enabled' : 'Disabled'}
                  </span>
                ) : (
                  row.value
                )}
              </TableCell>
              <TableCell className="text-sm text-muted-foreground">{row.description}</TableCell>
              <TableCell className="text-right space-x-2">
                {editingKey === row.key ? (
                  <>
                    <Button
                      size="sm"
                      onClick={() => handleSave(row.key)}
                    >
                      Save
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => setEditingKey(null)}
                    >
                      Cancel
                    </Button>
                  </>
                ) : (
                  <>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEdit(row)}
                    >
                      Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleReset(row.key)}
                    >
                      Reset
                    </Button>
                  </>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
```

#### C. New component: _components/system-status-cards.tsx

```typescript
// packages/react-admin/app/(protected)/settings/_components/system-status-cards.tsx
'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { CheckCircle2, XCircle, RefreshCw } from 'lucide-react';
import { useAdminApi } from '@/hooks/useAdminApi';
import { useToast } from '@/hooks/useToast';

interface SystemStatus {
  services: {
    twilio?: { configured: boolean; mode?: string };
    s3?: { configured: boolean; bucket?: string };
    ses?: { configured: boolean };
    fcm?: { configured: boolean };
    anthropic?: { configured: boolean };
    database?: { connected: boolean; poolSize?: number };
  };
  environment?: string;
  version?: string;
  nodeVersion?: string;
}

export function SystemStatusCards() {
  const [status, setStatus] = useState<SystemStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const { adminApi } = useAdminApi();
  const { toast } = useToast();

  useEffect(() => {
    loadStatus();
  }, []);

  const loadStatus = async () => {
    try {
      setLoading(true);
      const data = await adminApi.getSystemStatus();
      setStatus(data);
    } catch (error) {
      toast({ title: 'Error loading system status', description: String(error), variant: 'destructive' });
    } finally {
      setLoading(false);
    }
  };

  const StatusIcon = ({ active }: { active: boolean }) =>
    active ? (
      <CheckCircle2 className="w-5 h-5 text-green-600" />
    ) : (
      <XCircle className="w-5 h-5 text-red-600" />
    );

  const ServiceCard = ({ title, configured, details }: any) => (
    <div className="rounded-lg border p-4">
      <div className="flex items-center justify-between mb-2">
        <h3 className="font-semibold">{title}</h3>
        <StatusIcon active={configured} />
      </div>
      {details && <div className="text-sm text-muted-foreground">{details}</div>}
    </div>
  );

  if (loading) return <div>Loading...</div>;
  if (!status) return <div>Unable to load system status</div>;

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div className="text-sm text-muted-foreground">
          Environment: <span className="font-mono">{status.environment}</span> | Version:{' '}
          <span className="font-mono">{status.version}</span>
        </div>
        <Button
          size="sm"
          variant="outline"
          onClick={loadStatus}
          disabled={loading}
        >
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
        <ServiceCard
          title="Twilio"
          configured={status.services.twilio?.configured}
          details={status.services.twilio?.mode ? `Mode: ${status.services.twilio.mode}` : null}
        />
        <ServiceCard
          title="S3"
          configured={status.services.s3?.configured}
          details={status.services.s3?.bucket ? `Bucket: ${status.services.s3.bucket}` : null}
        />
        <ServiceCard
          title="SES"
          configured={status.services.ses?.configured}
        />
        <ServiceCard
          title="FCM"
          configured={status.services.fcm?.configured}
        />
        <ServiceCard
          title="Anthropic"
          configured={status.services.anthropic?.configured}
        />
        <ServiceCard
          title="Database"
          configured={status.services.database?.connected}
          details={status.services.database?.poolSize ? `Pool: ${status.services.database.poolSize}` : null}
        />
      </div>
    </div>
  );
}
```

#### D. Update: app/(protected)/layout.tsx or permissions gating

Ensure Settings page is gated to platformAdmin only (adjust the existing permission check pattern):

```typescript
// In app/(protected)/layout.tsx or a middleware
if (route === '/settings' && currentAdmin?.adminRole !== 'platformAdmin') {
  redirect('/unauthorized');
}
```

### 5. API Client Methods (packages/react-admin/lib/admin-api.ts or hooks/useAdminApi.ts)

Add these methods to the AdminApi client:

```typescript
async getPlatformConfig(): Promise<ConfigRow[]> {
  const res = await this.get('/admin/platform-config');
  return res;
}

async updatePlatformConfig(key: string, value: string): Promise<ConfigRow> {
  const res = await this.patch(`/admin/platform-config/${key}`, { value });
  return res;
}

async resetPlatformConfig(key: string): Promise<ConfigRow> {
  const res = await this.post(`/admin/platform-config/reset/${key}`);
  return res;
}

async getSystemStatus(): Promise<SystemStatus> {
  const res = await this.get('/admin/system-status');
  return res;
}
```

---

## Definition of Done

- [ ] Backend: `GET /admin/platform-config` endpoint implemented and tested
- [ ] Backend: `PATCH /admin/platform-config/:key` endpoint implemented and tested
- [ ] Backend: `POST /admin/platform-config/reset/:key` endpoint implemented and tested
- [ ] Backend: `GET /admin/system-status` endpoint implemented and tested
- [ ] Backend: All three endpoints require `authenticateAdmin` + `requirePlatformAdmin`
- [ ] Backend: Audit log entries created for every config update (verify in tests)
- [ ] Backend: Tests pass (`packages/api && npx jest platform-config system-status`)
- [ ] Frontend: Settings page created at `app/(protected)/settings/page.tsx`
- [ ] Frontend: Platform Config tab renders table with inline edit + reset buttons
- [ ] Frontend: Feature flag rows render as toggle switches
- [ ] Frontend: System Status tab renders service cards with status icons
- [ ] Frontend: Settings page is gated to platformAdmin only
- [ ] Frontend: API client methods added for all four endpoints
- [ ] All tests pass (Jest backend tests + React component renders)
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/C4-platform-config`
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

### What the next prompt in this track (C5) should know
-

---

## Interrogative Session

**Q1 (Agent perspective): Does the system status endpoint gracefully handle the database connectivity check without crashing the endpoint if the DB is unreachable?**
> Jeff:

**Q2 (Agent perspective): Are all secret filtering rules (key contains 'secret', 'key', 'token', 'password') working correctly in the GET endpoint, including case-insensitive matching?**
> Jeff:

**Q3 (Agent perspective): Does the React Settings page correctly render feature flags as toggle switches vs. regular inputs for non-feature keys?**
> Jeff:

**Q4 (Implementation perspective): Can admins successfully use the Reset button to restore multiple config keys to defaults in sequence without errors?**
> Jeff:

**Q5 (Integration perspective): Are audit log entries being created with the correct admin_id, timestamp, and oldValue/newValue for every config update?**
> Jeff:

**Ready for review:** ☐ Yes
