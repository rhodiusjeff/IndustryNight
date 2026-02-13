/// Validation utilities for user input

/// Validates a US phone number
/// Accepts formats: (123) 456-7890, 123-456-7890, 1234567890, +1234567890
bool isValidPhoneNumber(String phone) {
  // Remove all non-digit characters except leading +
  final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

  // US phone: 10 digits, or 11 with leading 1, or 12 with +1
  if (cleaned.startsWith('+1')) {
    return cleaned.length == 12;
  } else if (cleaned.startsWith('1')) {
    return cleaned.length == 11;
  } else {
    return cleaned.length == 10;
  }
}

/// Normalize a phone number to E.164 format (+1XXXXXXXXXX)
String normalizePhoneNumber(String phone) {
  final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

  if (digitsOnly.length == 10) {
    return '+1$digitsOnly';
  } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
    return '+$digitsOnly';
  } else if (digitsOnly.length == 11) {
    return '+1$digitsOnly';
  }

  return '+$digitsOnly';
}

/// Validates an email address
bool isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );
  return emailRegex.hasMatch(email);
}

/// Validates a URL
bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (_) {
    return false;
  }
}

/// Validates an Instagram handle
bool isValidInstagramHandle(String handle) {
  // Remove @ if present
  final cleaned = handle.startsWith('@') ? handle.substring(1) : handle;
  // Instagram: 1-30 chars, letters, numbers, periods, underscores
  final regex = RegExp(r'^[a-zA-Z0-9._]{1,30}$');
  return regex.hasMatch(cleaned);
}

/// Validates a TikTok handle
bool isValidTikTokHandle(String handle) {
  final cleaned = handle.startsWith('@') ? handle.substring(1) : handle;
  // TikTok: 2-24 chars, letters, numbers, periods, underscores
  final regex = RegExp(r'^[a-zA-Z0-9._]{2,24}$');
  return regex.hasMatch(cleaned);
}

/// Validates SMS verification code (6 digits)
bool isValidVerificationCode(String code) {
  return RegExp(r'^\d{6}$').hasMatch(code);
}

/// Validates a user bio (max 500 characters)
String? validateBio(String? bio) {
  if (bio == null || bio.isEmpty) return null;
  if (bio.length > 500) return 'Bio must be 500 characters or less';
  return null;
}

/// Validates a post content (1-2000 characters)
String? validatePostContent(String? content) {
  if (content == null || content.trim().isEmpty) {
    return 'Post content is required';
  }
  if (content.length > 2000) {
    return 'Post must be 2000 characters or less';
  }
  return null;
}

/// Validates a display name (1-50 characters)
String? validateDisplayName(String? name) {
  if (name == null || name.trim().isEmpty) {
    return 'Name is required';
  }
  if (name.length > 50) {
    return 'Name must be 50 characters or less';
  }
  return null;
}
