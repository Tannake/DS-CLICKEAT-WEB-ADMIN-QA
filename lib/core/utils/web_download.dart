import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [text] as a file named [filename].
///
/// Flutter-web only. A UTF-8 BOM is prepended so spreadsheet apps (Excel)
/// detect the encoding and render accented characters correctly.
void downloadTextFile(
  String filename,
  String text, {
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final bytes = utf8.encode('﻿$text');
  downloadBytesFile(filename, bytes, mimeType: mimeType);
}

/// Triggers a browser download of [bytes] as a file named [filename].
/// Flutter-web only — used for binary output such as generated PDFs.
void downloadBytesFile(
  String filename,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    <JSAny>[Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
