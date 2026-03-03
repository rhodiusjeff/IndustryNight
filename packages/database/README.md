# Industry Night Database

PostgreSQL database schema and migrations.

## Structure

```
database/
├── migrations/           # SQL migration files
│   ├── 001_baseline_schema.sql  # Complete schema (all tables, enums, triggers)
│   └── archive/          # Historical migrations (001-004, consolidated into baseline)
├── seeds/                # Seed data for development
│   ├── specialties.sql   # Reference data (27 specialties, idempotent)
│   └── dev_seed.sql      # Test data for local development
└── scripts/              # Utility scripts
```

## Migrations

The baseline schema (`001_baseline_schema.sql`) contains the complete database schema. Future migrations start at `002_*.sql`.

Migrations are tracked in the `_migrations` table — safe to re-run.

### Running Migrations

```bash
# Against remote DB (auto-manages port-forward)
DB_PASSWORD=xxx node scripts/migrate.js

# Against local DB (skip k8s tunnel)
DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s

# Check status only
DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s --status
```

### Resetting Database (Development)

```bash
# Full reset: drop all → apply migrations → load seeds
DB_PASSWORD=xxx node scripts/db-reset.js --skip-k8s --yes
```

## Tables Overview

### Core Tables
- `users` - Social user accounts (phone-based auth)
- `admin_users` - Admin accounts (email/password auth)
- `verification_codes` - SMS verification codes
- `events` - Industry Night events
- `event_images` - Up to 5 images per event (sort_order 0 = hero)
- `tickets` - Walk-in / manual check-in tickets
- `posh_orders` - Posh webhook purchases (canonical Posh ticket)
- `connections` - QR-scan mutual connections

### Content Tables
- `posts` - Community feed posts
- `post_comments` - Comments on posts
- `post_likes` - Post likes

### Business Tables
- `sponsors` - Business sponsors
- `event_sponsors` - Event-sponsor associations
- `discounts` - Sponsor discounts/perks
- `vendors` - Event vendors
- `event_vendors` - Event-vendor associations

### Reference & Analytics Tables
- `specialties` - Specialty reference data
- `venues` - Legacy venue records
- `audit_log` - System audit trail
- `analytics_*` - Anonymized analytics tables
- `data_export_requests` - GDPR/CCPA export tracking
