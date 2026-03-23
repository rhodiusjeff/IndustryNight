# [Track-C3] Image Assets Architecture — First-Class Image Registry

**Track:** C (Backend + Schema)
**Sequence:** 4 of 5 in Track C
**Model:** claude-opus-4-6
**Alternate Model:** gpt-5.4 ← preferred for architectural patterns and LLM service design
**A/B Test:** Yes ⚡ — run both models on `feature/C3-image-assets/claude` and `feature/C3-image-assets/gpt`; adversarial panel review before merging to `integration`
**Estimated Effort:** Large (12-16 hours)
**Dependencies:** C0 (Phase 0 Foundation), C1 (Event Schema), C2 (Admin Endpoints)

### C0 Winner Handoff (Control Session)

- Winner for C0 execution/apply authority: `gpt-5.3-codex` (control session decision).
- Source-of-truth migration: `packages/database/migrations/004_phase0_foundation.sql`.
- Assume these C0 outputs exist before implementing C3:
  - `admin_role` includes `platformAdmin`, `moderator`, `eventOps`
  - `llm_usage_log` exists and is available for image-tagging telemetry logging
  - `platform_config` exists for feature flags and runtime tuning
  - `user_role` no longer includes `venueStaff`
- Do not modify C0 migration in this prompt. Any additional schema work must be introduced as `003_*` or later.

---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (API services section, database section, tech stack)
- `docs/product/master_plan_v2.md` — Section 3.5 "Image Assets Table" (architectural goals)
- `packages/database/migrations/001_baseline_schema.sql` — baseline schema
- `packages/database/migrations/004_phase0_foundation.sql` — Phase 0 foundation (from C0)
- `packages/api/src/services/storage.ts` — current S3 upload implementation
- `packages/api/src/routes/admin.ts` — current event image endpoints (POST, PATCH, DELETE /admin/events/:id/images)
- `packages/api/src/__tests__/customers.test.ts` — test patterns (testcontainers, mocking S3)
- `packages/shared/lib/models/` — existing Dart models (Event, EventImage, Customer)

---

## Goal

Implement the `image_assets` table as a first-class image registry that replaces the current pattern of storing raw S3 URLs directly on events. Every image uploaded to the platform is tracked as an `image_asset` record with metadata (width, height, file size, MIME type), LLM-generated tags (via Haiku), and a three-phase lifecycle (active → archived → deleted). This architecture enables:

1. **Image reuse across events** — images stored once in the registry, referenced by multiple events
2. **Near-duplicate detection** — perceptual hash (pHash) on upload alerts admins to similar images
3. **Admin cleanup tools** — soft-delete (archive) before hard-delete, with restoration capability
4. **LLM tagging pipeline** — automated Haiku-powered background job that generates descriptive tags for search and categorization
5. **Future community reuse** — foundation for social users to browse and reuse approved event photos in their own posts

---

## Acceptance Criteria

### Database
- [ ] Migration file `003_image_assets.sql` exists at `packages/database/migrations/`
- [ ] `image_assets` table created with columns: `id UUID PRIMARY KEY`, `s3_key TEXT NOT NULL`, `s3_bucket TEXT NOT NULL`, `url TEXT NOT NULL`, `width INT`, `height INT`, `file_size_bytes BIGINT`, `mime_type TEXT`, `uploaded_by_admin_id UUID REFERENCES admin_users(id) ON DELETE SET NULL`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `archived_at TIMESTAMPTZ`, `deleted_at TIMESTAMPTZ`, `llm_tags JSONB DEFAULT NULL`, `similarity_hash TEXT`, `event_id UUID REFERENCES events(id) ON DELETE SET NULL`, `sort_order INT DEFAULT 0`, `is_hero BOOLEAN DEFAULT FALSE`
- [ ] Indexes created: `idx_image_assets_event_id`, `idx_image_assets_archived_at`, `idx_image_assets_similarity_hash`, `idx_image_assets_uploaded_by_admin_id`
- [ ] Existing `event_images` data migrated to `image_assets` (with s3_key extracted from URL, sort_order computed, is_hero inferred)
- [ ] `event_images` table dropped after migration (or archived separately)
- [ ] Constraint added: `archived_at IS NULL OR deleted_at IS NULL OR deleted_at > archived_at` (logical: can't be both deleted and active, and deletion must come after archival)

### API Services (packages/api/src/services/)
- [ ] `uploadImageAsAsset(buffer, filename, folder, adminId, eventId?)` added to `storage.ts` — uploads to S3, detects MIME type and dimensions, computes perceptual hash (pHash), creates `image_assets` record, returns full `ImageAsset` object
- [ ] `uploadImageAsAsset()` accepts optional `eventId` parameter (nullable)
- [ ] `uploadImageAsAsset()` response includes `{ asset: ImageAsset, similarImages?: ImageAsset[] }` if near-duplicates exist
- [ ] `archiveImage(assetId)` added — sets `archived_at = NOW()` (no S3 deletion)
- [ ] `deleteImageAsset(assetId)` added — validates `archived_at IS NOT NULL`, calls S3 `deleteObject()`, sets `deleted_at = NOW()`
- [ ] `storage.ts` gracefully degrades when S3 not configured (non-blocking pHash computation if sharp fails)

### Admin Routes (packages/api/src/routes/admin.ts)
- [ ] `POST /admin/events/:id/images` — calls `uploadImageAsAsset()`, inserts into `image_assets` (not `event_images`)
- [ ] `POST /admin/events/:id/images` returns `{ asset: ImageAsset, similarImages?: ImageAsset[] }` if duplicates found
- [ ] `DELETE /admin/events/:id/images/:imageId` — calls `archiveImage(imageId)` instead of direct S3 delete
- [ ] `PATCH /admin/events/:id/images/:imageId/hero` — updates `is_hero = true` on target, `is_hero = false` on previous hero
- [ ] `GET /admin/events/:id` — returns `images: ImageAsset[]` from `image_assets WHERE event_id = $1 AND deleted_at IS NULL ORDER BY sort_order`
- [ ] `GET /admin/images` — image catalog: all `image_assets WHERE deleted_at IS NULL`, includes event_name via JOIN, supports filtering by event, supports pagination
- [ ] `GET /admin/images/:assetId` — full asset detail including `llm_tags`, `similarity_hash`, creator info
- [ ] `POST /admin/images/:assetId/archive` — calls `archiveImage(assetId)`, returns updated asset
- [ ] `DELETE /admin/images/:assetId` — calls `deleteImageAsset(assetId)` after validating archived status, returns success/error
- [ ] `GET /admin/images/pending-tagging` — returns `{ images: ImageAsset[] }` where `llm_tags IS NULL AND archived_at IS NULL`, max 20 results, ordered by `created_at`
- [ ] `POST /admin/jobs/tag-images` — manual trigger for LLM tagging job (platformAdmin only), returns `{ tagged: N, skipped: M, errors: K, duration_ms: Z }`

### LLM Image Tagging Service (packages/api/src/services/image-tagger.ts)
- [ ] Service class `ImageTaggerService` created
- [ ] `tagImage(assetId: string, imageUrl: string): Promise<{ tags: string[], error?: string }>` — fetches image from S3 URL (via HTTP GET), sends to Anthropic Haiku API with structured prompt
- [ ] Prompt structure: "You are an image analyst for an industry night event platform. Analyze this image and generate 5-10 descriptive tags focusing on: setting (studio, event venue, outdoor, etc.), subject type (headshot, full body, group, product, equipment), lighting style, dominant colors, mood/atmosphere. Return ONLY a JSON array of lowercase tag strings, no explanations. Example: ["studio-lit", "headshot", "professional", "warm-tones", "confident-pose"]"
- [ ] Response parsing: extracts JSON array from response, validates it's an array of strings, stores in `image_assets.llm_tags`
- [ ] Graceful degradation: if `ANTHROPIC_API_KEY` not set, logs warning, sets `llm_tags = []` (empty array, not error)
- [ ] Rate limiting: uses `pLimit` or similar to enforce max 10 concurrent Haiku calls
- [ ] Error handling: on API failure, logs error, stores `llm_tags = [{ _error: true, message: "..." }]` (array with one object) so it doesn't retry infinitely on re-run
- [ ] Logs call metadata to `llm_usage_log` table: `feature = 'image_tagging'`, `model = 'claude-haiku-4-5-20251001'`, actual token counts from API response, `latency_ms`, success boolean

### Background Job (packages/api/src/jobs/tag-new-images.ts)
- [ ] Job class `TagNewImagesJob` created
- [ ] `run(): Promise<{ tagged: number, skipped: number, errors: number, duration_ms: number }>` — queries untagged images created in last 24 hours, processes up to 20 per run, calls `ImageTaggerService.tagImage()` for each
- [ ] Query: `SELECT id, url FROM image_assets WHERE llm_tags IS NULL AND archived_at IS NULL AND created_at > NOW() - INTERVAL '1 day' ORDER BY created_at ASC LIMIT 20`
- [ ] Registered in API startup (packages/api/src/index.ts): `setInterval(() => tagJob.run(), 15 * 60 * 1000)` (every 15 minutes)
- [ ] Errors caught and logged, job doesn't crash if one image fails
- [ ] Return value includes counts and duration for monitoring

### Scheduled Job Trigger (packages/api/src/routes/admin.ts)
- [ ] `POST /admin/jobs/tag-images` endpoint — calls `tagJob.run()` directly, returns result
- [ ] Requires `platformAdmin` role
- [ ] Useful for manual backfill when new images haven't been tagged yet

### Near-Duplicate Detection (Phase 1 — Basic pHash)
- [ ] Perceptual hash (pHash) computed on upload using `sharp` npm package
- [ ] Algorithm: `sharp(buffer).resize(8, 8).greyscale().raw().toBuffer()` → convert to bitstring → store as hex string in `similarity_hash`
- [ ] On upload: after computing pHash, query `SELECT id, url FROM image_assets WHERE similarity_hash = $1 AND deleted_at IS NULL LIMIT 3`
- [ ] If matches found: return them in upload response as `{ asset: ImageAsset, similarImages: ImageAsset[] }`
- [ ] NOT blocking — upload succeeds even if duplicates exist; admin can view and archive manually
- [ ] Database side: `similarity_hash` indexed for fast lookup

### Dart Models (packages/shared/lib/models/)
- [ ] `ImageAsset` model created in `image_asset.dart` (replacing concept of separate `EventImage` on the API side)
- [ ] Fields: `id`, `s3Key`, `url`, `eventId`, `sortOrder`, `isHero`, `llmTags`, `similarityHash`, `uploadedByAdminId`, `createdAt`, `archivedAt`, `deletedAt`, `fileSizeBytes`, `mimeType`, `width`, `height`
- [ ] Uses `@JsonSerializable(fieldRename: FieldRename.snake)` for snake_case JSON
- [ ] Includes `copyWith()` method for immutable updates
- [ ] `llmTags` field is `List<String>?` (null when not yet tagged)

### Admin App Flutter Updates (packages/admin-app/lib/)
- [ ] Import `ImageAsset` instead of `EventImage`
- [ ] Event detail screen: update image list binding to use `ImageAsset` model
- [ ] Event form screen: update image upload, preview, and deletion to use new asset endpoints
- [ ] Image catalog screen: update grid to display `ImageAsset` fields
- [ ] Admin API client (`admin_api.dart`): add new endpoints for image management

### TypeScript Types (packages/api/src/types/)
- [ ] `ImageAsset` interface defined with all fields (snake_case for DB, types include optional fields)
- [ ] `ImageUploadResponse` interface: `{ asset: ImageAsset, similarImages?: ImageAsset[] }`
- [ ] `JobResult` interface: `{ tagged: number, skipped: number, errors: number, duration_ms: number }`

---

## Technical Spec

### Database Migration: `003_image_assets.sql`

```sql
-- 003_image_assets.sql
-- Image Assets: first-class image registry with lifecycle (active → archived → deleted),
-- LLM tagging, and near-duplicate detection via perceptual hash

BEGIN;

-- ===== CREATE image_assets TABLE =====
CREATE TABLE IF NOT EXISTS image_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  s3_key TEXT NOT NULL,
  s3_bucket TEXT NOT NULL,
  url TEXT NOT NULL,
  width INT,
  height INT,
  file_size_bytes BIGINT,
  mime_type TEXT,
  uploaded_by_admin_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  llm_tags JSONB DEFAULT NULL,
  similarity_hash TEXT,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  sort_order INT DEFAULT 0,
  is_hero BOOLEAN DEFAULT FALSE
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_image_assets_event_id ON image_assets(event_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_image_assets_archived_at ON image_assets(archived_at) WHERE archived_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_image_assets_similarity_hash ON image_assets(similarity_hash) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_image_assets_uploaded_by_admin_id ON image_assets(uploaded_by_admin_id);

-- ===== MIGRATE DATA FROM event_images =====
-- Extract s3_key from URL by removing bucket prefix
INSERT INTO image_assets (id, s3_key, s3_bucket, url, event_id, sort_order, is_hero, created_at)
SELECT
  id,
  CASE
    WHEN url LIKE 'https://industrynight-assets-dev%' THEN SUBSTRING(url FROM LENGTH('https://industrynight-assets-dev.s3.amazonaws.com/') + 1)
    WHEN url LIKE 'https://industrynight-assets-prod%' THEN SUBSTRING(url FROM LENGTH('https://industrynight-assets-prod.s3.amazonaws.com/') + 1)
    ELSE url
  END AS s3_key,
  CASE
    WHEN url LIKE 'https://industrynight-assets-dev%' THEN 'industrynight-assets-dev'
    WHEN url LIKE 'https://industrynight-assets-prod%' THEN 'industrynight-assets-prod'
    ELSE 'industrynight-assets-dev'
  END AS s3_bucket,
  url,
  event_id,
  sort_order,
  (sort_order = 0) AS is_hero,
  uploaded_at
FROM event_images
WHERE deleted_at IS NULL;

-- ===== ARCHIVE event_images TABLE =====
-- Rename instead of dropping to preserve data history if needed
ALTER TABLE event_images RENAME TO event_images_archive;

-- ===== LIFECYCLE CONSTRAINT =====
-- Ensure logical consistency: images can be archived, then deleted, but not both simultaneously
-- (PostgreSQL doesn't support conditional constraints well, so this is enforced in application logic)
-- Constraint: For any row: archived_at IS NULL OR deleted_at IS NULL (can't be both)

COMMIT;
```

**Notes on migration:**
- Extraction of `s3_key` handles both dev and prod bucket URLs
- Null `uploaded_by_admin_id` for migrated records (we don't have upload history)
- `event_images_archive` is renamed instead of dropped for data safety during this large migration
- No deletion or hard removal of old event_images data
- Migration is idempotent (uses `IF NOT EXISTS` on tables and indexes)

### Storage Service Updates (packages/api/src/services/storage.ts)

```typescript
// Pseudo-code structure (TypeScript)

export interface ImageAsset {
  id: string;
  s3Key: string;
  s3Bucket: string;
  url: string;
  width?: number;
  height?: number;
  fileSizeBytes?: number;
  mimeType?: string;
  uploadedByAdminId?: string;
  createdAt: Date;
  archivedAt?: Date;
  deletedAt?: Date;
  llmTags?: string[];
  similarityHash?: string;
  eventId?: string;
  sortOrder: number;
  isHero: boolean;
}

export interface ImageUploadResponse {
  asset: ImageAsset;
  similarImages?: ImageAsset[];
}

export async function uploadImageAsAsset(
  buffer: Buffer,
  filename: string,
  folder: string,
  adminId: string,
  eventId?: string,
  db: any // postgres client
): Promise<ImageUploadResponse> {
  // 1. Detect MIME type and dimensions
  const image = sharp(buffer);
  const metadata = await image.metadata();
  const mimeType = metadata.format ? `image/${metadata.format}` : 'image/jpeg';
  const width = metadata.width;
  const height = metadata.height;

  // 2. Compute perceptual hash (pHash) for near-duplicate detection
  let similarityHash: string | undefined;
  try {
    const hashBuffer = await sharp(buffer)
      .resize(8, 8)
      .greyscale()
      .raw()
      .toBuffer();
    // Convert buffer to bitstring hex
    similarityHash = hashBuffer.toString('hex');
  } catch (err) {
    console.warn('pHash computation failed:', err);
    // Continue without hash — non-blocking failure
  }

  // 3. Upload to S3
  const s3Key = `${folder}/${Date.now()}-${filename}`;
  const url = await uploadToS3(buffer, s3Key, mimeType);

  // 4. Create image_assets record in database
  const asset = await db.query(
    `INSERT INTO image_assets
      (s3_key, s3_bucket, url, mime_type, width, height, file_size_bytes, similarity_hash, uploaded_by_admin_id, event_id)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    RETURNING *`,
    [s3Key, process.env.S3_BUCKET, url, mimeType, width, height, buffer.length, similarityHash, adminId, eventId || null]
  );

  const imageAsset = rowToImageAsset(asset.rows[0]);

  // 5. Check for near-duplicates
  let similarImages: ImageAsset[] = [];
  if (similarityHash) {
    const similar = await db.query(
      `SELECT * FROM image_assets WHERE similarity_hash = $1 AND id != $2 AND deleted_at IS NULL LIMIT 3`,
      [similarityHash, imageAsset.id]
    );
    similarImages = similar.rows.map(rowToImageAsset);
  }

  return { asset: imageAsset, similarImages: similarImages.length > 0 ? similarImages : undefined };
}

export async function archiveImage(assetId: string, db: any): Promise<ImageAsset> {
  const result = await db.query(
    `UPDATE image_assets SET archived_at = NOW() WHERE id = $1 RETURNING *`,
    [assetId]
  );
  return rowToImageAsset(result.rows[0]);
}

export async function deleteImageAsset(assetId: string, db: any): Promise<{ success: boolean }> {
  // Check archived status first
  const asset = await db.query(
    `SELECT archived_at FROM image_assets WHERE id = $1`,
    [assetId]
  );

  if (!asset.rows.length) throw new Error('Image asset not found');
  if (!asset.rows[0].archived_at) throw new Error('Image must be archived before deletion');

  // Delete from S3
  const assetRow = await db.query(
    `SELECT s3_key FROM image_assets WHERE id = $1`,
    [assetId]
  );
  await deleteFromS3(assetRow.rows[0].s3_key);

  // Mark as deleted in DB
  await db.query(
    `UPDATE image_assets SET deleted_at = NOW() WHERE id = $1`,
    [assetId]
  );

  return { success: true };
}

function rowToImageAsset(row: any): ImageAsset {
  return {
    id: row.id,
    s3Key: row.s3_key,
    s3Bucket: row.s3_bucket,
    url: row.url,
    width: row.width,
    height: row.height,
    fileSizeBytes: row.file_size_bytes,
    mimeType: row.mime_type,
    uploadedByAdminId: row.uploaded_by_admin_id,
    createdAt: row.created_at,
    archivedAt: row.archived_at,
    deletedAt: row.deleted_at,
    llmTags: row.llm_tags,
    similarityHash: row.similarity_hash,
    eventId: row.event_id,
    sortOrder: row.sort_order,
    isHero: row.is_hero,
  };
}
```

### Image Tagger Service (packages/api/src/services/image-tagger.ts)

```typescript
// Pseudo-code structure (TypeScript)

import * as Anthropic from '@anthropic-ai/sdk';
import pLimit from 'p-limit';

interface TagResult {
  tags: string[];
  error?: string;
}

export class ImageTaggerService {
  private client: Anthropic.Anthropic | null;
  private concurrencyLimit = pLimit(10);
  private db: any;

  constructor(db: any) {
    this.db = db;
    this.client = process.env.ANTHROPIC_API_KEY
      ? new Anthropic.default({ apiKey: process.env.ANTHROPIC_API_KEY })
      : null;
  }

  async tagImage(assetId: string, imageUrl: string): Promise<TagResult> {
    const startTime = Date.now();

    if (!this.client) {
      console.warn(`[ImageTagger] ANTHROPIC_API_KEY not set, skipping tagging for asset ${assetId}`);
      return { tags: [] };
    }

    try {
      // Fetch image from S3 URL
      const imageBuffer = await this.fetchImageFromUrl(imageUrl);
      const base64Image = imageBuffer.toString('base64');

      // Call Claude Haiku with vision
      const response = await this.client.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: 'image/jpeg',
                  data: base64Image,
                },
              },
              {
                type: 'text',
                text: 'You are an image analyst for an industry night event platform. Analyze this image and generate 5-10 descriptive tags focusing on: setting (studio, event venue, outdoor, etc.), subject type (headshot, full body, group, product, equipment), lighting style, dominant colors, mood/atmosphere. Return ONLY a JSON array of lowercase tag strings, no explanations or markdown. Example: ["studio-lit", "headshot", "professional", "warm-tones"]',
              },
            ],
          },
        ],
      });

      // Parse response
      const text = response.content[0].type === 'text' ? response.content[0].text : '[]';
      const tags = JSON.parse(text);

      if (!Array.isArray(tags) || !tags.every(t => typeof t === 'string')) {
        throw new Error('Invalid tag format from API');
      }

      // Store tags in DB
      await this.db.query(
        `UPDATE image_assets SET llm_tags = $1 WHERE id = $2`,
        [JSON.stringify(tags), assetId]
      );

      // Log to llm_usage_log
      const latencyMs = Date.now() - startTime;
      await this.db.query(
        `INSERT INTO llm_usage_log (feature, model, input_tokens, output_tokens, latency_ms, success)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          'image_tagging',
          'claude-haiku-4-5-20251001',
          response.usage.input_tokens,
          response.usage.output_tokens,
          latencyMs,
          true,
        ]
      );

      return { tags };
    } catch (error) {
      console.error(`[ImageTagger] Error tagging asset ${assetId}:`, error);

      // Store error flag to prevent infinite retry
      const errorObj = [{ _error: true, message: String(error) }];
      await this.db.query(
        `UPDATE image_assets SET llm_tags = $1 WHERE id = $2`,
        [JSON.stringify(errorObj), assetId]
      );

      const latencyMs = Date.now() - startTime;
      await this.db.query(
        `INSERT INTO llm_usage_log (feature, model, latency_ms, success, error)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          'image_tagging',
          'claude-haiku-4-5-20251001',
          latencyMs,
          false,
          String(error),
        ]
      );

      return { tags: [], error: String(error) };
    }
  }

  private async fetchImageFromUrl(url: string): Promise<Buffer> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.statusText}`);
    return Buffer.from(await response.arrayBuffer());
  }
}
```

### Tag New Images Job (packages/api/src/jobs/tag-new-images.ts)

```typescript
// Pseudo-code structure (TypeScript)

export class TagNewImagesJob {
  private taggerService: ImageTaggerService;
  private db: any;

  constructor(taggerService: ImageTaggerService, db: any) {
    this.taggerService = taggerService;
    this.db = db;
  }

  async run(): Promise<{ tagged: number; skipped: number; errors: number; duration_ms: number }> {
    const startTime = Date.now();
    let tagged = 0;
    let skipped = 0;
    let errors = 0;

    // Query untagged images from last 24 hours
    const result = await this.db.query(
      `SELECT id, url FROM image_assets
       WHERE llm_tags IS NULL AND archived_at IS NULL AND created_at > NOW() - INTERVAL '24 hours'
       ORDER BY created_at ASC
       LIMIT 20`
    );

    for (const asset of result.rows) {
      try {
        const tagResult = await this.taggerService.tagImage(asset.id, asset.url);
        if (tagResult.error) {
          errors++;
        } else {
          tagged++;
        }
      } catch (err) {
        console.error(`[TagNewImagesJob] Unexpected error tagging ${asset.id}:`, err);
        errors++;
      }
    }

    skipped = result.rows.length - tagged - errors;
    const duration = Date.now() - startTime;

    console.log(
      `[TagNewImagesJob] Completed: ${tagged} tagged, ${skipped} skipped, ${errors} errors in ${duration}ms`
    );

    return { tagged, skipped, errors, duration_ms: duration };
  }
}
```

### API Startup Registration (packages/api/src/index.ts)

```typescript
// Pseudo-code: in main Express app setup

import { ImageTaggerService } from './services/image-tagger';
import { TagNewImagesJob } from './jobs/tag-new-images';

const taggerService = new ImageTaggerService(db);
const tagJob = new TagNewImagesJob(taggerService, db);

// Register 15-minute interval
setInterval(() => {
  tagJob.run().catch(err => console.error('TagNewImagesJob error:', err));
}, 15 * 60 * 1000);

// Also export for manual triggers
export { tagJob };
```

### Admin Routes: Image Management (packages/api/src/routes/admin.ts)

```typescript
// Pseudo-code: new endpoints added to admin router

// POST /admin/events/:id/images — upload image for event
router.post('/events/:id/images', authenticateAdmin, async (req, res) => {
  const { id: eventId } = req.params;
  const file = req.file; // from multer
  const adminId = req.user.userId;

  try {
    const uploadResponse = await uploadImageAsAsset(
      file.buffer,
      file.originalname,
      `events/${eventId}`,
      adminId,
      eventId,
      db
    );

    // If similar images exist, admin can review
    res.json(uploadResponse);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// DELETE /admin/events/:id/images/:imageId — archive (soft delete)
router.delete('/events/:id/images/:imageId', authenticateAdmin, async (req, res) => {
  const { imageId } = req.params;

  try {
    const asset = await archiveImage(imageId, db);
    res.json({ success: true, asset });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// PATCH /admin/events/:id/images/:imageId/hero — set as hero
router.patch('/events/:id/images/:imageId/hero', authenticateAdmin, async (req, res) => {
  const { id: eventId, imageId } = req.params;

  try {
    // Set all others to non-hero
    await db.query(
      `UPDATE image_assets SET is_hero = false WHERE event_id = $1 AND is_hero = true`,
      [eventId]
    );

    // Set this one as hero
    const result = await db.query(
      `UPDATE image_assets SET is_hero = true, sort_order = 0 WHERE id = $1 RETURNING *`,
      [imageId]
    );

    res.json(rowToImageAsset(result.rows[0]));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// GET /admin/images — catalog of all images
router.get('/images', authenticateAdmin, async (req, res) => {
  const { eventId, limit = '50', offset = '0' } = req.query;

  try {
    let query = `SELECT ia.*, e.name as event_name FROM image_assets ia
                 LEFT JOIN events e ON ia.event_id = e.id
                 WHERE ia.deleted_at IS NULL`;
    const params: any[] = [];

    if (eventId) {
      params.push(eventId);
      query += ` AND ia.event_id = $${params.length}`;
    }

    query += ` ORDER BY ia.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await db.query(query, params);
    const images = result.rows.map(rowToImageAsset);

    res.json({ images, total: result.rows.length });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// GET /admin/images/:assetId — full asset detail
router.get('/images/:assetId', authenticateAdmin, async (req, res) => {
  const { assetId } = req.params;

  try {
    const result = await db.query(
      `SELECT ia.*, au.name as uploaded_by_name FROM image_assets ia
       LEFT JOIN admin_users au ON ia.uploaded_by_admin_id = au.id
       WHERE ia.id = $1`,
      [assetId]
    );

    if (!result.rows.length) return res.status(404).json({ error: 'Asset not found' });

    res.json(rowToImageAsset(result.rows[0]));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// POST /admin/images/:assetId/archive — manually archive
router.post('/images/:assetId/archive', authenticateAdmin, async (req, res) => {
  const { assetId } = req.params;

  try {
    const asset = await archiveImage(assetId, db);
    res.json({ success: true, asset });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// DELETE /admin/images/:assetId — hard delete (requires archive first)
router.delete('/images/:assetId', authenticateAdmin, async (req, res) => {
  const { assetId } = req.params;

  try {
    await deleteImageAsset(assetId, db);
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// GET /admin/images/pending-tagging — images awaiting LLM tags
router.get('/images/pending-tagging', authenticateAdmin, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM image_assets
       WHERE llm_tags IS NULL AND archived_at IS NULL
       ORDER BY created_at ASC
       LIMIT 20`
    );

    res.json({ images: result.rows.map(rowToImageAsset) });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// POST /admin/jobs/tag-images — manual trigger for tagging
router.post('/jobs/tag-images', authenticateAdmin, requirePlatformAdmin, async (req, res) => {
  try {
    const result = await tagJob.run();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

---

## Test Suite

### File: `packages/api/src/__tests__/image-assets.test.ts`

```typescript
describe('Image Assets', () => {
  it('POST /admin/events/:id/images creates image_assets record', async () => {
    // Upload image
    // Verify image_assets row created with correct fields
    // Verify S3 URL set
  });

  it('POST /admin/events/:id/images returns similarImages when duplicate detected', async () => {
    // Upload same image twice with same pHash
    // Second upload response includes similarImages array
  });

  it('DELETE /admin/events/:id/images/:imageId soft-deletes (archives)', async () => {
    // Upload, then delete
    // Verify archived_at set, deleted_at NULL
    // Verify image still queryable (but excluded from default lists)
    // Verify file still exists in S3
  });

  it('DELETE /admin/images/:assetId hard-deletes only if archived', async () => {
    // Try to hard-delete unarchived image: 400 error
    // Archive, then hard-delete: success, file removed from S3, deleted_at set
  });

  it('GET /admin/events/:id returns images from image_assets', async () => {
    // Create event, upload 2 images
    // GET /admin/events/:id includes images array with correct sort_order and is_hero
  });

  it('GET /admin/images lists all non-deleted images', async () => {
    // Upload images for multiple events
    // GET /admin/images returns all, includes event_name
  });

  it('PATCH /admin/events/:id/images/:imageId/hero sets hero and updates sort_order', async () => {
    // Upload 2 images (first is hero by default)
    // PATCH second as hero
    // Verify first has is_hero=false, second has is_hero=true and sort_order=0
  });
});
```

### File: `packages/api/src/__tests__/image-tagger.test.ts`

```typescript
describe('ImageTaggerService', () => {
  it('skips tagging gracefully when ANTHROPIC_API_KEY not set', async () => {
    // Mock ANTHROPIC_API_KEY as undefined
    // tagImage() should return { tags: [] } with no API call
  });

  it('calls Haiku API with image and stores tags as JSON', async () => {
    // Mock Anthropic API to return ["studio", "headshot", "professional"]
    // Verify image_assets.llm_tags = ["studio", "headshot", "professional"]
  });

  it('parses and validates JSON response', async () => {
    // Mock API to return invalid JSON
    // Error should be caught, llm_tags set to [{ _error: true, ... }]
  });

  it('logs to llm_usage_log with correct token counts', async () => {
    // Mock Anthropic response with token usage
    // Verify llm_usage_log row created with input_tokens, output_tokens, latency_ms
  });

  it('handles API errors gracefully without infinite retry', async () => {
    // Mock API to throw error
    // Verify llm_tags set to error object (not null, so won't retry)
    // Verify llm_usage_log has success=false and error message
  });
});
```

### File: `packages/api/src/__tests__/tag-new-images.test.ts`

```typescript
describe('TagNewImagesJob', () => {
  it('only processes images where llm_tags IS NULL', async () => {
    // Create 3 images: 2 untagged, 1 already tagged
    // run() should process only 2
  });

  it('limits to 20 images per run', async () => {
    // Create 25 untagged images
    // run() processes max 20
  });

  it('includes images created in last 24 hours in query', async () => {
    // Create old untagged image (>24h)
    // Create recent untagged image (<24h)
    // run() should skip old one
  });

  it('returns { tagged, skipped, errors, duration_ms }', async () => {
    // run() result has correct shape
  });

  it('continues on individual image tagging error', async () => {
    // Mock tagger to fail on one image
    // Job should continue with others, errors incremented
  });
});
```

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin managing event images, I can view all uploaded images in one catalog even across events | Enabled by `GET /admin/images` with global image registry |
| Platform Admin | When I upload an image that looks nearly identical to an existing one, I see a warning with the similar image and can archive the duplicate | pHash on upload detects similarity; response includes `similarImages` array |
| Platform Admin | I can soft-delete images (archive them), and they're removed from the active catalog but still recoverable; only permanently deleted images are gone from S3 | Distinction between archived (soft) and deleted (hard) states |
| Platform Admin | Every image I upload is automatically analyzed by Haiku within 15 minutes, and descriptive tags appear in the image detail view | Automated LLM pipeline with Haiku |
| Event Ops | I can manually trigger the tagging job via `POST /admin/jobs/tag-images` if I need to backfill tags | On-demand trigger for operational flexibility |
| System | Every LLM image tagging call is logged to `llm_usage_log` with tokens, latency, and success status so that platform costs and performance can be monitored | Observability for LLM costs |
| Future: Social User | I can browse a curated gallery of approved event photos and reuse them in my own posts | Architecture supports this; implementation in later phase |

---

## Definition of Done

- [ ] Migration `003_image_assets.sql` committed and applied successfully
- [ ] `image_assets` table exists with all columns and indexes
- [ ] Existing `event_images` data migrated to `image_assets` correctly
- [ ] `event_images_archive` table exists (renamed, not dropped)
- [ ] `uploadImageAsAsset()` function in `storage.ts` creates asset records and computes pHash
- [ ] `archiveImage()` and `deleteImageAsset()` functions implemented with correct validation
- [ ] All admin image endpoints updated to use `image_assets` table
- [ ] `ImageTaggerService` implemented with Haiku integration and error handling
- [ ] `TagNewImagesJob` registered in API startup, runs every 15 minutes
- [ ] `POST /admin/jobs/tag-images` manual trigger endpoint working
- [ ] `ImageAsset` Dart model created in shared package with all fields
- [ ] Admin app Flutter code updated to use `ImageAsset` instead of `EventImage`
- [ ] Test suites in place for image-assets, image-tagger, and tag-new-images
- [ ] All tests passing (unit + integration with testcontainers)
- [ ] Near-duplicate detection working (pHash computed, similar images returned in upload response)
- [ ] Graceful degradation when `ANTHROPIC_API_KEY` not set
- [ ] `llm_usage_log` entries created for each Haiku call with correct metrics
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff
- [ ] (A/B) Adversarial panel review complete — see `docs/codex/reviews/C3-adversarial-review.md`

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/C3-image-assets/[claude|gpt]`
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

### Architectural decisions made (A/B evaluation note)
> If running the `/claude` branch: describe which architectural decisions you made that differ from the alternative options in the spec (e.g., job scheduling approach, error handling strategy, image registry pattern).
>
> If running the `/gpt` branch: same request — note specific architectural choices made and trade-offs considered.

-

### What the next prompt in this track (C4) should know
-

---

## Interrogative Session

**Q1: Does the migration apply cleanly and do all manual verification commands pass as expected?**
> Jeff:

**Q2: When ANTHROPIC_API_KEY is not set, does the system gracefully degrade without logging spam or breaking the job?**
> Jeff:

**Q3: How does the pHash-based duplicate detection perform? Any false positives observed in testing?**
> Jeff:

**A/B Panel Review Prompt:**
> Reviewers should specifically compare:
> 1. **Image lifecycle design** — how each model implements the archive → delete flow and enforces the constraint that deletion requires prior archival
> 2. **LLM job architecture** — setInterval vs. node-cron vs. worker_threads; error handling and retry strategy
> 3. **pHash implementation quality** — perceptual hash algorithm, false positive/negative rates, performance
> 4. **Database migration strategy** — data migration completeness, idempotency, handling of edge cases (null values, duplicate URLs, etc.)
> 5. **TypeScript types and async patterns** — how cleanly types flow through the codebase; error handling in concurrent tagging scenarios

**Ready for review:** ☐ Yes
