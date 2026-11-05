import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'socket_service.dart';

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

  bool _isBusy = false;
  String _statusMessage = "Sunucuya bağlanılıyor...";
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.hourglass_top;
  int _frameCounter = 0;
  bool _isConnected = false;

  // Veri toplama modu
  bool _isCollectionMode = false;
  int _collectedCount = 0;

  // Animasyonlar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool _showSuccess = false;

  static const String serverUrl = 'http://172.20.10.3:5000';

  // ── Sıcak Renk Paleti ──
  static const Color warmOrange = Color(0xFFFF6B35);
  static const Color warmRed = Color(0xFFE63946);
  static const Color warmYellow = Color(0xFFF4A261);
  static const Color warmGold = Color(0xFFFF9F1C);
  static const Color darkBg = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();

    // Hedef gösterge pulse animasyonu
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animasyonu
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
    _socketService.connect(serverUrl);

    _socketService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (connected) {
          _statusMessage = _isCollectionMode
              ? "Veri toplamaya hazır"
              : "Bağlı — Elinizi gösterin";
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
      if (!_isCollectionMode) {
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
            // Başarı animasyonu sonra sıfırla
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _showSuccess = false);
            });
          } else {
            _statusMessage =
                "Yanlış: $prediction  →  Hedef: ${widget.targetLetter}";
            _statusColor = warmRed;
            _statusIcon = Icons.close;
            _showSuccess = false;
          }
        });
      }
    });

    // Veri toplama durumu
    _socketService.collectionStream.listen((data) {
      setState(() {
        String status = data['status'] ?? '';
        if (status == 'saved') {
          _collectedCount = data['count'] ?? 0;
          _statusMessage = "Kaydedildi: $_collectedCount görüntü";
          _statusColor = warmGold;
          _statusIcon = Icons.save;
        } else if (status == 'started') {
          _statusMessage = "VERİ TOPLAMA AKTİF";
          _statusColor = warmRed;
          _statusIcon = Icons.fiber_manual_record;
        } else if (status == 'stopped') {
          _statusMessage = "Toplam: $_collectedCount görüntü kaydedildi";
          _statusColor = const Color(0xFF2ECC71);
          _statusIcon = Icons.check_circle;
          _isCollectionMode = false;
        }
      });
    });
  }

  void _toggleCollectionMode() {
    setState(() {
      _isCollectionMode = !_isCollectionMode;
      if (_isCollectionMode) {
        _socketService.startCollection(widget.targetLetter);
        _collectedCount = 0;
      } else {
        _socketService.stopCollection();
      }
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
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

    _controller!.startImageStream((image) {
      if (!_isBusy && _isConnected) {
        _isBusy = true;
        _processCameraImage(image);
      }
    });
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    _frameCounter++;
    int frameSkip = _isCollectionMode ? 4 : 6;
    if (_frameCounter % frameSkip != 0) {
      _isBusy = false;
      return;
    }

    try {
      img.Image? image = _convertYUV420ToImage(cameraImage);
      if (image == null) {
        _isBusy = false;
        return;
      }

      int width = _isCollectionMode ? 480 : 320;
      int height = _isCollectionMode ? 360 : 240;
      int quality = _isCollectionMode ? 85 : 75;

      img.Image resized = img.copyResize(image, width: width, height: height);
      Uint8List jpegBytes =
          Uint8List.fromList(img.encodeJpg(resized, quality: quality));

      _socketService.sendFrame(jpegBytes);
    } catch (e) {
      print("Frame işleme hatası: $e");
    } finally {
      _isBusy = false;
    }
  }

  img.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      var imgBuffer = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int r = (yp + 1.402 * (vp - 128)).round();
          int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
          int b = (yp + 1.772 * (up - 128)).round();

          imgBuffer.setPixelRgb(
              x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
        }
      }

      var rotated = img.copyRotate(imgBuffer, angle: -90);
      return img.flipHorizontal(rotated);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _socketService.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━ Glassmorphism container ━━━━━━━━━━━━━━━
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
              CircularProgressIndicator(
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
      body: Stack(
        children: [
          // ── Kamera Önizleme ──
          SizedBox.expand(child: CameraPreview(_controller!)),

          // ── Başarı Glow Efekti ──
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
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
            ),

          // ── Üst Bar (Glassmorphism) ──
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
                      // Geri butonu
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

                      // Bağlantı durumu
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
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isConnected
                                            ? const Color(0xFF2ECC71)
                                            : warmRed)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? "Bağlı" : "Bağlantı Yok",
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

                      // Veri toplama butonu
                      GestureDetector(
                        onTap: _isConnected ? _toggleCollectionMode : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isCollectionMode
                                  ? [warmRed, const Color(0xFFD62828)]
                                  : [warmOrange, warmGold],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_isCollectionMode ? warmRed : warmOrange)
                                        .withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCollectionMode
                                    ? Icons.stop_rounded
                                    : Icons.add_a_photo_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isCollectionMode ? "DURDUR" : "VERİ TOPLA",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Hedef Göstergesi (Sağ üst) ──
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
                    _isCollectionMode ? "TOPLANIYOR" : "HEDEF",
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
                            colors: _isCollectionMode
                                ? [
                                    warmRed.withValues(alpha: 0.8),
                                    const Color(0xFFD62828)
                                        .withValues(alpha: 0.8)
                                  ]
                                : [
                                    darkBg.withValues(alpha: 0.7),
                                    darkBg.withValues(alpha: 0.5)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isCollectionMode
                                ? warmRed
                                : warmOrange.withValues(
                                    alpha: _glowAnimation.value),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isCollectionMode ? warmRed : warmOrange)
                                  .withValues(
                                      alpha: _glowAnimation.value * 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.targetLetter,
                          style: GoogleFonts.poppins(
                            color: _isCollectionMode ? Colors.white : warmGold,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_isCollectionMode) ...[
                    const SizedBox(height: 8),
                    _glassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      borderRadius: BorderRadius.circular(12),
                      child: Text(
                        "$_collectedCount görüntü",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Alt Durum Çubuğu (Glassmorphism) ──
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
