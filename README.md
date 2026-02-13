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
- [Melos](https://melos.invertase.dev/) (`dart pub global activate melos`)
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

3. Bootstrap the monorepo:
   ```bash
   melos bootstrap
   ```

### Development

**Start the API:**
```bash
melos run dev:api
# or
./scripts/run-api.sh
```

**Start the mobile app:**
```bash
melos run dev:mobile
# or
./scripts/run-mobile.sh
```

**Start the web app:**
```bash
melos run dev:web
# or
./scripts/run-web.sh
```

### Testing

```bash
# Run all tests
melos run test

# Run API tests only
melos run test:api
```

### Code Generation

After modifying models with JSON serialization:
```bash
melos run build_runner
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
