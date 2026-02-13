# Industry Night Shared Package

Shared Dart code for Industry Night mobile and web applications.

## Contents

- **Models:** Data classes with JSON serialization
- **API Client:** HTTP client for REST API communication
- **Constants:** Enums and reference data
- **Utils:** Validators, formatters, and storage helpers

## Usage

Add to your `pubspec.yaml`:

```yaml
dependencies:
  industrynight_shared:
    path: ../shared
```

Import the package:

```dart
import 'package:industrynight_shared/shared.dart';
```

## Code Generation

After modifying models, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```
