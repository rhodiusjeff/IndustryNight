import 'package:flutter_test/flutter_test.dart';
import 'package:industrynight_shared/shared.dart';

void main() {
  group('Phone number validation', () {
    test('accepts valid US E.164 phone number', () {
      expect(isValidPhoneNumber('+15555550001'), isTrue);
      expect(isValidPhoneNumber('+12125551234'), isTrue);
    });

    test('accepts 10-digit local format (no country code)', () {
      expect(isValidPhoneNumber('5555550001'), isTrue);
    });

    test('accepts 11-digit format with leading 1', () {
      expect(isValidPhoneNumber('15555550001'), isTrue);
    });

    test('accepts formatted numbers with dashes (strips punctuation)', () {
      expect(isValidPhoneNumber('+1555-555-0001'), isTrue);
    });

    test('rejects too-short numbers', () {
      expect(isValidPhoneNumber('+1555'), isFalse);
      expect(isValidPhoneNumber('555'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidPhoneNumber(''), isFalse);
    });
  });

  group('Phone number normalization', () {
    test('normalizes 10-digit number to E.164', () {
      final result = normalizePhoneNumber('5555550001');
      expect(result, equals('+15555550001'));
    });

    test('normalizes 11-digit number with leading 1 to E.164', () {
      final result = normalizePhoneNumber('15555550001');
      expect(result, equals('+15555550001'));
    });

    test('passes through already-normalized E.164 number', () {
      final result = normalizePhoneNumber('+15555550001');
      expect(result, equals('+15555550001'));
    });
  });
}
