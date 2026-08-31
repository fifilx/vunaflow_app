/// Shared validation helpers so every form (registration, profile edit,
/// staff creation, password reset) enforces the same rules consistently.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a numeric amount as a KSh string with thousands-separator commas.
/// e.g. 450000 → "KSh 450,000"
String fmtKsh(dynamic value) {
  final num = double.tryParse(value.toString()) ?? 0;
  final fmt = NumberFormat('#,##0', 'en_US');
  return 'KSh ${fmt.format(num)}';
}

/// Same as [fmtKsh] but returns just the formatted number without "KSh" prefix.
String fmtNum(dynamic value) {
  final num = double.tryParse(value.toString()) ?? 0;
  final fmt = NumberFormat('#,##0', 'en_US');
  return fmt.format(num);
}

/// Formats large amounts compactly, e.g. 1200000 -> "1.2M", 450000 -> "450K".
String fmtCompact(dynamic value) {
  final num = double.tryParse(value.toString()) ?? 0;
  if (num >= 1000000) {
    final m = num / 1000000;
    return m % 1 == 0 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  } else if (num >= 1000) {
    final k = num / 1000;
    return k % 1 == 0 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  }
  return num.toStringAsFixed(0);
}


/// Formatter that automatically capitalizes the first letter of each word
/// in real time as the user types (works across Web, Desktop, iOS, and Android).
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  const CapitalizeWordsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;
    final StringBuffer buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ' || char == '-' || char == "'" || char == '.') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    final formattedText = buffer.toString();
    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Formatter that capitalizes the first letter of the sentence / input only.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;
    final formattedText = text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : '');

    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Validates a Kenyan mobile number. Accepts 07XXXXXXXX, 01XXXXXXXX,
/// 2547XXXXXXXX, 2541XXXXXXXX, +2547XXXXXXXX, +2541XXXXXXXX (spaces and
/// dashes are ignored). Returns an error message, or null if valid.
String? validateKenyanPhone(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your phone number';
  final digits = value.replaceAll(RegExp(r'[^\d+]'), '');

  String normalized;
  if (digits.startsWith('+254')) {
    normalized = digits.substring(1);
  } else if (digits.startsWith('254')) {
    normalized = digits;
  } else if (digits.startsWith('0')) {
    normalized = '254${digits.substring(1)}';
  } else {
    return 'Enter a valid Kenyan number, e.g. 0712345678 or +254712345678';
  }

  if (!RegExp(r'^254[71]\d{8}$').hasMatch(normalized)) {
    return 'Enter a valid Kenyan number, e.g. 0712345678 or +254712345678';
  }
  return null;
}

/// Normalizes a Kenyan phone number to +254XXXXXXXXX for sending to the API.
/// Assumes the value already passed [validateKenyanPhone].
String normalizeKenyanPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('+254')) return digits;
  if (digits.startsWith('254')) return '+$digits';
  if (digits.startsWith('0')) return '+254${digits.substring(1)}';
  return value;
}

/// Password rule: at least 8 characters.
String? validatePassword(String? value) {
  if (value == null || value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

/// Confirm-password rule: must match the original password.
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'Please confirm your password';
  if (value != password) return 'Passwords do not match';
  return null;
}

/// Kenyan National ID: 7 or 8 digits only.
String? validateNationalId(String? value) {
  if (value == null || value.trim().isEmpty) return null; // optional field
  if (!RegExp(r'^\d{7,8}$').hasMatch(value.trim())) {
    return 'National ID must be 7 or 8 digits';
  }
  return null;
}

/// Returns true if the given date of birth makes someone 18 or older today.
bool isAtLeast18(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age >= 18;
}
