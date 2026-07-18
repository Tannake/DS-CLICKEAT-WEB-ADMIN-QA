import 'picked_image.dart';

/// Non-web fallback. Image picking is only supported on the web build.
Future<PickedImage?> pickImageFile() async {
  throw UnsupportedError('La selección de imágenes solo está disponible en web.');
}
