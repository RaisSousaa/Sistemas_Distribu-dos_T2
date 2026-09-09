import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreparedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

class ImageService {
  static const int maxWidth = 1280;
  static const int jpegQuality = 80;

  Future<PreparedImage> prepareImage(String imagePath) async {
    final File file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Arquivo da imagem não encontrado.');
    }

    final Uint8List originalBytes = await file.readAsBytes();

    final img.Image? decodedImage = img.decodeImage(originalBytes);

    if (decodedImage == null) {
      throw Exception('Não foi possível decodificar a imagem.');
    }

    img.Image processedImage = decodedImage;

    if (decodedImage.width > maxWidth) {
      processedImage = img.copyResize(decodedImage, width: maxWidth);
    }

    final Uint8List jpegBytes = img.encodeJpg(
      processedImage,
      quality: jpegQuality,
    );

    return PreparedImage(
      bytes: jpegBytes,
      width: processedImage.width,
      height: processedImage.height,
    );
  }
}
