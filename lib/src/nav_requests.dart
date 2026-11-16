import 'package:flutter/material.dart';

/// Cross-screen tab requests (e.g. receipt → "View my orders").
final ValueNotifier<int?> customerTabRequest = ValueNotifier(null);

/// Asks the verify screen to search for a specific order number (null clears).
final ValueNotifier<String?> receiptLookupRequest = ValueNotifier(null);

/// Asks the verify screen to open the scanner for a specific order number and
/// claim it after a successful scan (null clears).
final ValueNotifier<String?> receiptScanRequest = ValueNotifier(null);
