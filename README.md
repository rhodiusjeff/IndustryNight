# Industry Night

Mobile app + companion website for discovering, promoting, and managing industry night events for creative workers (hair stylists, makeup artists, photographers, videographers, producers, directors).

## Project Structure

```
industrynight/
├── packages/
│   ├── api/            # Node.js/TypeScript REST API
│   ├── database/       # Database schema & migrations
│   ├── shared/         # Shared Dart package (models, API client)
│   ├── mobile-app/     # Flutter mobile app (iOS + Android)
│   └── web-app/        # Flutter web app (admin dashboard)
├── infrastructure/     # AWS/K8s configuration
├── scripts/            # Developer utilities
└── docs/               # Documentation
```

## Tech Stack

- **Frontend:** Flutter (shared codebase for mobile and web)
- **Backend:** Node.js/TypeScript REST API with JWT authentication
- **Database:** PostgreSQL (AWS RDS)
- **Infrastructure:** AWS EKS (Kubernetes)
- **Authentication:** Phone number verification via SMS (passwordless)

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
   cd packages/mobile-app && flutter pub get && cd ../..
   cd packages/web-app && flutter pub get && cd ../..
   ```

### Development

**Start the API:**
```bash
cd packages/api && npm run dev
# or
./scripts/run-api.sh
```

**Start the mobile app:**
```bash
cd packages/mobile-app && flutter run
# or
./scripts/run-mobile.sh
```

**Start the web app:**
```bash
cd packages/web-app && flutter run -d chrome
# or
./scripts/run-web.sh
```

### Testing

```bash
# Run mobile app tests
cd packages/mobile-app && flutter test

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
         mobile-app         web-app
```

- **shared:** Contains data models and API client used by both Flutter apps
- **api:** REST backend, consumes database schema
- **mobile-app:** End-user app (browse events, network, check-in)
- **web-app:** Admin dashboard (manage users, events, sponsors)

## License

Proprietary - All rights reserved
