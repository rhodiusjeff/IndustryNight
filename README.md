# Industry Night

Platform for discovering, promoting, and managing industry night events for creative workers (hair stylists, makeup artists, photographers, videographers, producers, directors).

## Project Structure

```
industrynight/
├── packages/
│   ├── api/            # Node.js/TypeScript REST API
│   ├── database/       # Database schema & migrations
│   ├── shared/         # Shared Dart package (models, API client)
│   ├── social-app/     # Social networking app (iOS, Android, Web)
│   └── admin-app/      # Admin dashboard app (Web, iOS, Android)
├── infrastructure/     # AWS/K8s configuration
├── scripts/            # Developer utilities
└── docs/               # Documentation
```

## Tech Stack

- **Social App:** Flutter/Dart (iOS, Android, Web) — mobile-first
- **Admin App:** Flutter/Dart (Web, iOS, Android) — web-first
- **Shared Library:** Flutter/Dart package with models, API clients, constants
- **Backend:** Node.js/TypeScript REST API with JWT authentication
- **Database:** PostgreSQL 15 (AWS RDS)
- **Infrastructure:** AWS EKS (Kubernetes)
- **Auth:** Phone + SMS OTP for social users; email/password for admin users

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.16+)
- [Node.js](https://nodejs.org/) (20 LTS)
- [Dart](https://dart.dev/get-dart) (3.2+)
- [Docker](https://www.docker.com/) (for local development)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/industrynight.git
   cd industrynight
   ```

2. Run the setup script:
   ```bash
   ./scripts/setup-local.sh
   ```

3. Install dependencies:
   ```bash
   cd packages/shared && flutter pub get && cd ../..
   cd packages/social-app && flutter pub get && cd ../..
   cd packages/admin-app && flutter pub get && cd ../..
   ```

### Development

**Start the API:**
```bash
cd packages/api && npm run dev
# or
./scripts/run-api.sh
```

**Start the social app (mobile):**
```bash
cd packages/social-app && flutter run
# or
./scripts/run-mobile.sh
```

**Start the admin app (web):**
```bash
cd packages/admin-app && flutter run -d chrome
# or
./scripts/run-web.sh
```

### Testing

```bash
# Run social app tests
cd packages/social-app && flutter test

# Run admin app tests
cd packages/admin-app && flutter test

# Run API tests
cd packages/api && npm test
```

### Code Generation

After modifying models with JSON serialization:
```bash
cd packages/shared && dart run build_runner build --delete-conflicting-outputs
```

## Documentation

- [Requirements](docs/requirements.md) - Product requirements and MVP scope
- [Implementation Plan](docs/implementation_plan.md) - Development roadmap
- [AWS Architecture](docs/aws_architecture.md) - Infrastructure details

## Architecture

### Package Dependencies

```
database ──▶ api ◀── shared
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
         social-app         admin-app
```

- **shared:** Contains data models and API client used by both Flutter apps
- **api:** REST backend, consumes database schema
- **social-app:** Social networking app (browse events, make connections, community feed)
- **admin-app:** Admin dashboard (manage users, events, sponsors, moderation)

## License

Proprietary - All rights reserved
