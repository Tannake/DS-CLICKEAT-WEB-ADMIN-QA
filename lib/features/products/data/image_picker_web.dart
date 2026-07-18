import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'picked_image.dart';

/// Opens the browser's file chooser (filtered to JPEG) and returns the picked
/// file's bytes, or `null` if the user cancelled.
Future<PickedImage?> pickImageFile() {
  final completer = Completer<PickedImage?>();
  final input =
      web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = '.jpg,.jpeg,image/jpeg';

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      final buffer = reader.result as JSArrayBuffer;
      completer.complete(PickedImage(file.name, buffer.toDart.asUint8List()));
    }).toJS;
    reader.onerror = ((web.Event _) {
      completer.complete(null);
    }).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  input.click();
  return completer.future;
}
