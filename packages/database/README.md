# Industry Night Database

PostgreSQL database schema and migrations.

## Structure

```
database/
├── migrations/        # SQL migration files
├── seeds/             # Seed data for development
└── scripts/           # Utility scripts
```

## Migrations

Migrations are numbered SQL files that run in order:
- `001_initial_schema.sql` - Core tables
- `002_add_sponsors.sql` - Sponsors and discounts
- etc.

### Running Migrations

```bash
./scripts/migrate.sh
```

### Resetting Database (Development)

```bash
./scripts/reset.sh
```

## Tables Overview

### Core Tables
- `users` - User accounts
- `verification_codes` - SMS verification codes
- `events` - Industry Night events
- `tickets` - Event tickets
- `connections` - User networking connections

### Content Tables
- `posts` - Community feed posts
- `post_comments` - Comments on posts
- `post_likes` - Post likes

### Business Tables
- `sponsors` - Business sponsors
- `discounts` - Sponsor discounts/perks
- `vendors` - Event vendors

## Environment Variables

Required for scripts:
- `DB_HOST` - Database host (default: localhost)
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password (or use `PGPASSWORD`)
