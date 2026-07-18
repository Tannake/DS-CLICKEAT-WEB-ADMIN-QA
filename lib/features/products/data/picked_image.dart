import 'dart:typed_data';

/// A file picked from the user's machine, ready to upload.
class PickedImage {
  final String name;
  final Uint8List bytes;
  const PickedImage(this.name, this.bytes);

  /// True when the file name ends in a JPEG extension (the only type the
  /// backend accepts).
  bool get isJpg {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
  }
}
