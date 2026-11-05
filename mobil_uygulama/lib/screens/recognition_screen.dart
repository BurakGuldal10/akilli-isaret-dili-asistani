import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../providers/app_state.dart';
import '../services/image_converter.dart';
import '../services/socket_service.dart';

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
  final AppState _appState = AppState.instance;
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
    _socketService.connect(_appState.serverUrl);

    _socketService.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (connected) {
          _statusMessage = "Bağlı — Elinizi gösterin";
          _statusColor = AppTheme.warmOrange;
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
          _statusColor = AppTheme.warmYellow;
          _statusIcon = Icons.pan_tool_alt;
          _showSuccess = false;
        } else if (prediction == widget.targetLetter) {
          _statusMessage = "DOĞRU: $prediction";
          _statusColor = AppTheme.successGreen;
          _statusIcon = Icons.check_circle;
          _showSuccess = true;
          _appState.markLetterLearned(widget.targetLetter);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showSuccess = false);
          });
        } else {
          _statusMessage =
              "Algılanan: $prediction  →  Hedef: ${widget.targetLetter}";
          _statusColor = AppTheme.warmRed;
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

      final desiredDirection = _appState.useFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == desiredDirection,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (kIsWeb) {
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
          _statusColor = AppTheme.warmRed;
        });
      }
    }
  }

  Future<void> _captureWebFrame() async {
    if (_isBusy ||
        !_isConnected ||
        _controller == null ||
        !_controller!.value.isInitialized) {
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
      final jpegBytes = await compute(convertYuvToJpegIsolate, {
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
    final textController = TextEditingController(text: _appState.serverUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Sunucu Adresi',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
              borderSide: const BorderSide(color: AppTheme.warmOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warmOrange,
            ),
            onPressed: () {
              final newUrl = textController.text.trim();
              _appState.setServerUrl(newUrl);
              setState(() {
                _statusMessage = "Yeniden bağlanılıyor...";
              });
              _socketService.connect(newUrl);
              Navigator.pop(context);
            },
            child: Text(
              'Bağlan',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
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
            color: AppTheme.darkBg.withValues(alpha: 0.55),
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
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.warmOrange),
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
      backgroundColor: AppTheme.darkBg,
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
                    color: AppTheme.successGreen.withValues(alpha: 0.6),
                    width: 4,
                  ),
                ),
              ),
            ),
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
                        AppTheme.darkBg.withValues(alpha: 0.7),
                        AppTheme.darkBg.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.warmOrange.withValues(alpha: 0.2),
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
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _glassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                                    ? AppTheme.successGreen
                                    : AppTheme.warmRed,
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
                      _glassContainer(
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _showServerSettingsDialog,
                          child: const Icon(
                            Icons.settings_ethernet,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black87),
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
                              AppTheme.darkBg.withValues(alpha: 0.7),
                              AppTheme.darkBg.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.warmOrange.withValues(
                              alpha: _glowAnimation.value,
                            ),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warmOrange.withValues(
                                alpha: _glowAnimation.value * 0.5,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.targetLetter,
                          style: GoogleFonts.poppins(
                            color: AppTheme.warmGold,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
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
