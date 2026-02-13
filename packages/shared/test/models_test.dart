import 'package:test/test.dart';
import 'package:industrynight_shared/shared.dart';

void main() {
  group('User', () {
    test('fromJson creates user correctly', () {
      final json = {
        'id': '123',
        'phone': '+11234567890',
        'email': 'test@example.com',
        'name': 'John Doe',
        'bio': 'Test bio',
        'role': 'user',
        'source': 'app',
        'specialties': ['photographer', 'videographer'],
        'verificationStatus': 'verified',
        'profileCompleted': true,
        'banned': false,
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, '123');
      expect(user.phone, '+11234567890');
      expect(user.name, 'John Doe');
      expect(user.role, UserRole.user);
      expect(user.isVerified, true);
      expect(user.specialties, ['photographer', 'videographer']);
    });

    test('copyWith creates new instance with changes', () {
      final user = User(
        id: '123',
        phone: '+11234567890',
        name: 'John Doe',
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(name: 'Jane Doe');

      expect(updated.name, 'Jane Doe');
      expect(updated.id, '123');
      expect(updated.phone, '+11234567890');
    });
  });

  group('Event', () {
    test('isUpcoming returns true for future events', () {
      final event = Event(
        id: '1',
        name: 'Test Event',
        venueId: 'v1',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 4)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(event.isUpcoming, true);
      expect(event.isPast, false);
    });

    test('isPast returns true for past events', () {
      final event = Event(
        id: '1',
        name: 'Test Event',
        venueId: 'v1',
        startTime: DateTime.now().subtract(const Duration(days: 2)),
        endTime: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(event.isPast, true);
      expect(event.isUpcoming, false);
    });
  });

  group('Validators', () {
    test('isValidPhoneNumber accepts valid formats', () {
      expect(isValidPhoneNumber('1234567890'), true);
      expect(isValidPhoneNumber('(123) 456-7890'), true);
      expect(isValidPhoneNumber('+11234567890'), true);
      expect(isValidPhoneNumber('123-456-7890'), true);
    });

    test('isValidPhoneNumber rejects invalid formats', () {
      expect(isValidPhoneNumber('123'), false);
      expect(isValidPhoneNumber('123456789'), false); // 9 digits
    });

    test('isValidEmail validates email addresses', () {
      expect(isValidEmail('test@example.com'), true);
      expect(isValidEmail('invalid'), false);
      expect(isValidEmail('no@domain'), false);
    });

    test('normalizePhoneNumber converts to E.164', () {
      expect(normalizePhoneNumber('1234567890'), '+11234567890');
      expect(normalizePhoneNumber('(123) 456-7890'), '+11234567890');
      expect(normalizePhoneNumber('+11234567890'), '+11234567890');
    });
  });
}
