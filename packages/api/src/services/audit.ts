import { Request } from 'express';
import { query } from '../config/database';
import { config } from '../config/env';

type AuditAction =
  | 'create'
  | 'update'
  | 'delete'
  | 'login'
  | 'logout'
  | 'verify'
  | 'reject'
  | 'ban'
  | 'unban'
  | 'checkin';

type ActorType = 'user' | 'admin' | 'system';
type AuditResult = 'success' | 'failure';

interface AuditEventInput {
  action: AuditAction;
  entityType: string;
  entityId?: string | null;
  actorType: ActorType;
  actorId?: string | null;
  adminActorId?: string | null;
  result: AuditResult;
  failureReason?: string | null;
  requestId?: string | null;
  route?: string | null;
  method?: string | null;
  statusCode?: number | null;
  sourceIp?: string | null;
  userAgent?: string | null;
  oldValues?: Record<string, unknown> | null;
  newValues?: Record<string, unknown> | null;
  metadata?: Record<string, unknown> | null;
}

function compactObject(obj: Record<string, unknown> | null | undefined): Record<string, unknown> | null {
  if (!obj) return null;

  const entries = Object.entries(obj).filter(([, value]) => value !== undefined);
  return entries.length > 0 ? Object.fromEntries(entries) : null;
}

function normalizeUserAgent(userAgent: string | undefined): string | null {
  if (!userAgent) return null;
  return userAgent.slice(0, 512);
}

function extractSourceIp(req: Request): string | null {
  const forwarded = req.header('x-forwarded-for');
  if (forwarded) {
    const firstIp = forwarded.split(',')[0]?.trim();
    if (firstIp) return firstIp;
  }
  return req.ip || null;
}

export async function logAuditEvent(event: AuditEventInput): Promise<void> {
  if (!config.audit.enabled) {
    return;
  }

  const oldValues = compactObject(event.oldValues);
  const newValues = compactObject(event.newValues);
  const metadata = compactObject(event.metadata);

  await query(
    `INSERT INTO audit_log (
      action,
      entity_type,
      entity_id,
      actor_id,
      admin_actor_id,
      actor_type,
      result,
      failure_reason,
      request_id,
      route,
      method,
      status_code,
      source_ip,
      user_agent,
      environment,
      metadata_version,
      old_values,
      new_values,
      metadata,
      occurred_at,
      ingested_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8,
      $9, $10, $11, $12, $13, $14, $15, $16,
      $17, $18, $19, NOW(), NOW()
    )`,
    [
      event.action,
      event.entityType,
      event.entityId ?? null,
      event.actorId ?? null,
      event.adminActorId ?? null,
      event.actorType,
      event.result,
      event.failureReason ?? null,
      event.requestId ?? null,
      event.route ?? null,
      event.method ?? null,
      event.statusCode ?? null,
      event.sourceIp ?? null,
      event.userAgent ?? null,
      config.audit.environment,
      config.audit.metadataVersion,
      oldValues,
      newValues,
      metadata,
    ]
  );
}

type RequestAuditInput = Omit<AuditEventInput, 'requestId' | 'route' | 'method' | 'sourceIp' | 'userAgent'>;

export async function logSecurityEventFromRequest(req: Request, event: RequestAuditInput): Promise<void> {
  await logAuditEvent({
    ...event,
    requestId: req.requestId ?? null,
    route: req.originalUrl,
    method: req.method,
    sourceIp: extractSourceIp(req),
    userAgent: normalizeUserAgent(req.header('user-agent')),
  });
}

export async function tryLogSecurityEventFromRequest(req: Request, event: RequestAuditInput): Promise<void> {
  try {
    await logSecurityEventFromRequest(req, event);
  } catch (error) {
    console.error('[AUDIT] Failed to write audit event', {
      action: event.action,
      entityType: event.entityType,
      error,
    });
  }
}
