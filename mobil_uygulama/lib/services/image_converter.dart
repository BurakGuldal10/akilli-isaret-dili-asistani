import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Arka plan Isolate içinde YUV420 kamera verisini 320x240 JPEG formatına dönüştürür.
Uint8List? convertYuvToJpegIsolate(Map<String, dynamic> params) {
  try {
    final int width = params['width'];
    final int height = params['height'];
    final Uint8List yBytes = params['yBytes'];
    final Uint8List uBytes = params['uBytes'];
    final Uint8List vBytes = params['vBytes'];
    final int uvRowStride = params['uvRowStride'];
    final int uvPixelStride = params['uvPixelStride'];

    final imgBuffer = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final int yp = yBytes[index];
        final int up = uBytes[uvIndex];
        final int vp = vBytes[uvIndex];

        int r = (yp + 1.402 * (vp - 128)).round();
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
        int b = (yp + 1.772 * (up - 128)).round();

        imgBuffer.setPixelRgb(
          x,
          y,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        );
      }
    }

    final rotated = img.copyRotate(imgBuffer, angle: -90);
    final flipped = img.flipHorizontal(rotated);
    final resized = img.copyResize(flipped, width: 320, height: 240);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  } catch (_) {
    return null;
  }
}
