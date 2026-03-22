import 'package:intl/intl.dart';

/// Format a phone number for display
/// Input: +12345678901 → Output: (234) 567-8901
String formatPhoneNumber(String phone) {
  final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

  // Get last 10 digits
  final tenDigits =
      digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;

  if (tenDigits.length != 10) return phone;

  return '(${tenDigits.substring(0, 3)}) ${tenDigits.substring(3, 6)}-${tenDigits.substring(6)}';
}

/// Format a date for display (e.g., "Jan 15, 2024")
String formatDate(DateTime date) {
  return DateFormat.yMMMd().format(date);
}

/// Format a date and time for display (e.g., "Jan 15, 2024 at 7:00 PM")
String formatDateTime(DateTime dateTime) {
  return '${DateFormat.yMMMd().format(dateTime)} at ${DateFormat.jm().format(dateTime)}';
}

/// Format event time range (e.g., "7:00 PM - 11:00 PM")
String formatTimeRange(DateTime start, DateTime end) {
  final startTime = DateFormat.jm().format(start);
  final endTime = DateFormat.jm().format(end);
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  if (!sameDay) {
    final endDate = DateFormat.MMMd().format(end);
    return '$startTime - $endDate $endTime';
  }

  return '$startTime - $endTime';
}

/// Format event date with time range
String formatEventDateTime(DateTime start, DateTime end) {
  final date = DateFormat.MMMEd().format(start); // "Sat, Jan 15"
  final timeRange = formatTimeRange(start, end);
  return '$date • $timeRange';
}

/// Format relative time (e.g., "2 hours ago", "3 days ago")
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  } else {
    return DateFormat.yMMMd().format(dateTime);
  }
}

/// Format a count with abbreviation (e.g., 1500 → "1.5K")
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value.truncate() == value ? 0 : 1)}K';
  }
  final value = count / 1000000;
  return '${value.toStringAsFixed(value.truncate() == value ? 0 : 1)}M';
}

/// Format currency
String formatCurrency(double amount, {String symbol = '\$'}) {
  return '$symbol${amount.toStringAsFixed(2)}';
}

/// Truncate text with ellipsis
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

/// Format a list of specialties for display
String formatSpecialties(List<String> specialties, {int maxDisplay = 3}) {
  if (specialties.isEmpty) return '';
  if (specialties.length <= maxDisplay) return specialties.join(' • ');
  return '${specialties.take(maxDisplay).join(' • ')} +${specialties.length - maxDisplay}';
}

/// Get initials from a name (e.g., "John Doe" → "JD")
String getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';

  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length == 1) {
    return words[0].substring(0, 1).toUpperCase();
  }

  return '${words[0][0]}${words.last[0]}'.toUpperCase();
}
