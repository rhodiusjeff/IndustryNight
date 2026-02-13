# Industry Night Web Admin

Flutter web application for platform administration.

## Features

- Dashboard with analytics
- User management (view, edit, ban, verify)
- Event management (create, edit, publish)
- Sponsor and discount management
- Vendor management
- Post moderation
- Announcements

## Getting Started

### Prerequisites

- Flutter SDK 3.16+
- Chrome browser

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run -d chrome
   ```

## Project Structure

```
lib/
├── main.dart           # App entry point
├── app.dart            # App widget and configuration
├── config/
│   └── routes.dart     # Navigation routes
├── features/
│   ├── auth/           # Admin login
│   ├── dashboard/      # Dashboard and analytics
│   ├── users/          # User management
│   ├── events/         # Event management
│   ├── sponsors/       # Sponsor and discount management
│   ├── vendors/        # Vendor management
│   ├── moderation/     # Post moderation
│   └── settings/       # Admin settings
├── shared/
│   ├── widgets/        # Reusable widgets
│   └── theme/          # Admin theming
└── providers/
    └── admin_state.dart  # Admin state
```

## Building

```bash
flutter build web --release
```

The output will be in `build/web/`.

## Deployment

The web app is deployed to S3 + CloudFront. See the CI/CD pipeline for details.
