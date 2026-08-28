import 'dart:io';

import 'package:flutter/services.dart';

/// Runs on-device text recognition on a photographed receipt and pulls out
/// a best-guess total amount, so Add Expense's amount field can be
/// prefilled instead of typed by hand.
///
/// Talks to a native bridge per platform (Apple's Vision framework on
/// iOS, Android's ML Kit as a direct Gradle dependency on Android) rather
/// than a single cross-platform Flutter plugin — Google's ML Kit iOS pods
/// ship no arm64 simulator slice, which this environment's arm64-only
/// simulator runtime can't work around. See ios/Runner/
/// ReceiptScannerBridge.swift and android/.../ReceiptScannerBridge.kt.
class ReceiptScannerService {
  ReceiptScannerService._();
  static final instance = ReceiptScannerService._();

  static const _channel = MethodChannel('com.srigautham.waypoint/receipt_scanner');

  static final _moneyPattern = RegExp(r'\$?\s?(\d{1,4}[.,]\d{2})\b');

  /// Returns the best-guess total, or null if nothing amount-like was
  /// found in the receipt (including if recognition itself isn't
  /// available/fails — errs on "just let the user type it in").
  Future<double?> scanTotal(File image) async {
    String? text;
    try {
      text = await _channel.invokeMethod<String>('recognizeText', {'path': image.path});
    } catch (_) {
      return null;
    }
    if (text == null) return null;

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Prefer a line that says "total" but not "subtotal" — grand total
    // tends to be the last such line on a receipt (after any subtotal/tax
    // breakdown), so scan bottom-up and take the first hit.
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      if (lower.contains('total') && !lower.contains('subtotal')) {
        final amount = _amountIn(line);
        if (amount != null) return amount;
      }
    }

    // No labeled total found — fall back to the largest amount-shaped
    // number anywhere on the receipt (commonly the total on simple
    // receipts without an explicit "Total" line).
    double? largest;
    for (final line in lines) {
      final amount = _amountIn(line);
      if (amount != null && (largest == null || amount > largest)) {
        largest = amount;
      }
    }
    return largest;
  }

  double? _amountIn(String line) {
    final match = _moneyPattern.firstMatch(line);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }
}
