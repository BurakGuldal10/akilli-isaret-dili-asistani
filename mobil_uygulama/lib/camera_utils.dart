import 'package:camera/camera.dart';
import 'package:image/image.dart' as img; // pubspec.yaml'a eklediğimiz 'image' paketi

class CameraUtils {
  /// Kameradan gelen YUV420 formatındaki ham görüntüyü
  /// Yapay zeka modelinin anlayacağı RGB formatına (img.Image) çevirir.
  static img.Image? convertYUV420ToImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      // Boş bir resim buffer'ı oluştur
      var imgBuffer = img.Image(width: width, height: height);

      // Pikselleri tek tek dönüştür
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          // YUV formülünden RGB'ye geçiş
          int r = (yp + (1.370705 * (vp - 128))).toInt();
          int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).toInt();
          int b = (yp + (1.732446 * (up - 128))).toInt();

          // Sınırları 0-255 arasında tut
          imgBuffer.setPixelRgb(x, y, 
            r.clamp(0, 255), 
            g.clamp(0, 255), 
            b.clamp(0, 255)
          );
        }
      }
      
      // Ön kamera görüntüsü genellikle yan döner (270 derece).
      // Bunu düzeltmek için görüntüyü -90 derece döndürüyoruz.
      return img.copyRotate(imgBuffer, angle: -90);
    } catch (e) {
      print("Görüntü dönüştürme hatası: $e");
      return null;
    }
  }
}