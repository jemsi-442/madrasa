import 'dart:io';

import 'package:flutter/services.dart';

bool get financeDownloadsSupported => Platform.isAndroid;

Future<bool> saveFinanceCsv(String filename, String csv) async {
  if (!financeDownloadsSupported) {
    throw UnsupportedError('CSV saving is not available on this platform.');
  }
  return await const MethodChannel(
        'mif/finance-export',
      ).invokeMethod<bool>('saveCsv', {'filename': filename, 'content': csv}) ??
      false;
}
