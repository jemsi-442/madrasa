import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get reportDownloadsSupported => true;
Future<void> saveReportPdf(String filename, String base64) async {
  final bytes = base64Decode(base64);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Keep the object alive long enough for the browser download to start.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
