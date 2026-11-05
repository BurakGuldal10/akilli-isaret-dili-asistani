import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'socket_service.dart';

/// Arka plan Isolate içinde YUV420 verisini 320x240 JPEG formatına dönüştürür.
/// Böylece mobil cihazda ana ekran (UI thread) hiç kasmaz ve telefon ısınmaz.
Uint8List? _convertYuvToJpegIsolate(Map<String, dynamic> params) {
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

class RecognitionScreen extends StatefulWidget {
  final String targetLetter;
  const RecognitionScreen({super.key, required this.targetLetter});

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  final SocketService _socketService = SocketService();
  Timer? _webFrameTimer;

  bool _isBusy = false;
  String _statusMessage = "Sunucuya bağlanılıyor...";
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.hourglass_top;
  int _frameCounter = 0;
  bool _isConnected = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool _showSuccess = false;

  static String _serverUrl = const String.fromEnvironment(
    'SERVER_URL',
    defaultValue: kIsWeb ? 'http://localhost:5000' : 'http://172.20.10.3:5000',
  );

  static const Color warmOrange = Color(0xFFFF6B35);
  static const Color warmRed = Color(0xFFE63946);
  static const Color warmYellow = Color(0xFFF4A261);
  static const Color warmGold = Color(0xFFFF9F1C);
  static const Color darkBg = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initializeCamera();
    _connectToServer();
  }

  void _connectToServer() {
    _socketService.connect(_serverUrl);

    _socketService.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (connected) {
          _statusMessage = "Bağlı — Elinizi gösterin";
          _statusColor = warmOrange;
          _statusIcon = Icons.front_hand;
        } else {
          _statusMessage = "Sunucu bağlantısı yok";
          _statusColor = Colors.grey;
          _statusIcon = Icons.cloud_off;
        }
      });
    });

    _socketService.predictionStream.listen((prediction) {
      if (!mounted) return;
      setState(() {
        if (prediction == "...") {
          _statusMessage = "El algılanamıyor...";
          _statusColor = warmYellow;
          _statusIcon = Icons.pan_tool_alt;
          _showSuccess = false;
        } else if (prediction == widget.targetLetter) {
          _statusMessage = "DOĞRU: $prediction";
          _statusColor = const Color(0xFF2ECC71);
          _statusIcon = Icons.check_circle;
          _showSuccess = true;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showSuccess = false);
          });
        } else {
          _statusMessage =
              "Algılanan: $prediction  →  Hedef: ${widget.targetLetter}";
          _statusColor = warmRed;
          _statusIcon = Icons.close;
          _showSuccess = false;
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (kIsWeb) {
        // Web tarayıcılarında startImageStream desteklenmediği için periyodik kare yakalanır
        _webFrameTimer = Timer.periodic(
          const Duration(milliseconds: 350),
          (_) => _captureWebFrame(),
        );
      } else {
        _controller!.startImageStream((image) {
          if (!_isBusy && _isConnected) {
            _isBusy = true;
            _processCameraImage(image);
          }
        });
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Kamera erişim hatası";
          _statusColor = warmRed;
        });
      }
    }
  }

  Future<void> _captureWebFrame() async {
    if (_isBusy || !_isConnected || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _isBusy = true;
    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      _socketService.sendFrame(bytes);
    } catch (_) {
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    _frameCounter++;
    if (_frameCounter % 6 != 0) {
      _isBusy = false;
      return;
    }

    try {
      final jpegBytes = await compute(_convertYuvToJpegIsolate, {
        'width': cameraImage.width,
        'height': cameraImage.height,
        'yBytes': Uint8List.fromList(cameraImage.planes[0].bytes),
        'uBytes': Uint8List.fromList(cameraImage.planes[1].bytes),
        'vBytes': Uint8List.fromList(cameraImage.planes[2].bytes),
        'uvRowStride': cameraImage.planes[1].bytesPerRow,
        'uvPixelStride': cameraImage.planes[1].bytesPerPixel ?? 1,
      });

      if (jpegBytes != null) {
        _socketService.sendFrame(jpegBytes);
      }
    } catch (_) {
    } finally {
      _isBusy = false;
    }
  }

  void _showServerSettingsDialog() {
    final textController = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Sunucu Adresi',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'http://192.168.1.x:5000',
            hintStyle: GoogleFonts.poppins(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: warmOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: warmOrange),
            onPressed: () {
              setState(() {
                _serverUrl = textController.text.trim();
                _statusMessage = "Yeniden bağlanılıyor...";
              });
              _socketService.connect(_serverUrl);
              Navigator.pop(context);
            },
            child: Text('Bağlan', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webFrameTimer?.cancel();
    _controller?.dispose();
    _socketService.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Widget _glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: darkBg.withValues(alpha: 0.55),
            borderRadius: br,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: darkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(warmOrange),
              ),
              const SizedBox(height: 16),
              Text(
                'Kamera başlatılıyor...',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(_controller!)),

          if (_showSuccess)
            AnimatedOpacity(
              opacity: _showSuccess ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.6),
                    width: 4,
                  ),
                ),
              ),
            ),

          // Üst Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        darkBg.withValues(alpha: 0.7),
                        darkBg.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: warmOrange.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _glassContainer(
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _glassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isConnected
                                    ? const Color(0xFF2ECC71)
                                    : warmRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? "Sunucu Bağlı" : "Bağlantı Yok",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Sunucu Ayar Butonu
                      _glassContainer(
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _showServerSettingsDialog,
                          child: const Icon(Icons.settings_ethernet,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Hedef Göstergesi (Sağ üst)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Column(
                children: [
                  Text(
                    "HEDEF HARF",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [
                        const Shadow(blurRadius: 4, color: Colors.black87),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              darkBg.withValues(alpha: 0.7),
                              darkBg.withValues(alpha: 0.5)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: warmOrange.withValues(
                                alpha: _glowAnimation.value),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: warmOrange.withValues(
                                  alpha: _glowAnimation.value * 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.targetLetter,
                          style: GoogleFonts.poppins(
                            color: warmGold,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Alt Durum Çubuğu
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _statusColor.withValues(alpha: 0.75),
                        _statusColor.withValues(alpha: 0.50),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_statusIcon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
