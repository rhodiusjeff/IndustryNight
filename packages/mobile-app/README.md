# Industry Night Mobile App

Flutter mobile application for iOS and Android.

## Features

- Phone number authentication (SMS verification)
- Browse upcoming events
- QR code networking (scan to connect)
- Community feed with posts
- Sponsor perks and discounts
- User profiles with verification

## Getting Started

### Prerequisites

- Flutter SDK 3.16+
- Xcode (for iOS)
- Android Studio (for Android)

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run code generation:
   ```bash
   dart run build_runner build
   ```

3. Run the app:
   ```bash
   # iOS
   flutter run -d ios

   # Android
   flutter run -d android
   ```

## Project Structure

```
lib/
├── main.dart           # App entry point
├── app.dart            # App widget and configuration
├── config/
│   └── routes.dart     # Navigation routes
├── features/
│   ├── auth/           # Authentication screens
│   ├── onboarding/     # Profile setup
│   ├── events/         # Event browsing
│   ├── networking/     # QR scanning and connections
│   ├── community/      # Feed and posts
│   ├── search/         # User search
│   ├── profile/        # User profile
│   └── perks/          # Sponsor discounts
├── shared/
│   ├── widgets/        # Reusable widgets
│   └── theme/          # App theming
└── providers/
    └── app_state.dart  # Global state
```

## Architecture

- **State Management:** Provider
- **Navigation:** go_router
- **API Client:** Shared package (industrynight_shared)

## Testing

```bash
flutter test
```

## Building

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```
