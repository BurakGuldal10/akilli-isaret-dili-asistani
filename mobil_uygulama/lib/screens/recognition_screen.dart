import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../models/letter_info.dart';
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

  late String _currentLetter;
  bool _isBusy = false;
  int _frameCounter = 0;
  bool _isConnected = false;

  // Durum ve Hata Mesajı Yönetimi
  String _statusTitle = "Sunucuya bağlanılıyor...";
  String? _errorDetail;
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.hourglass_top;

  // Sabit Tutarak Doğrulama (Hold-to-Confirm)
  static const int _requiredHoldSteps = 3;
  int _correctHoldSteps = 0;
  int _consecutiveWrongSteps = 0;
  bool _isLetterCompleted = false;
  bool _showErrorBorder = false;
  bool _showTipBanner = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentLetter = widget.targetLetter;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeCamera();
    _connectToServer();
  }

  int get _currentLetterIndex =>
      LetterInfo.alphabets.indexOf(_currentLetter).clamp(0, LetterInfo.alphabets.length - 1);

  void _changeTargetLetter(int newIndex) {
    if (newIndex < 0 || newIndex >= LetterInfo.alphabets.length) return;
    setState(() {
      _currentLetter = LetterInfo.alphabets[newIndex];
      _correctHoldSteps = 0;
      _consecutiveWrongSteps = 0;
      _isLetterCompleted = false;
      _showErrorBorder = false;
      _errorDetail = null;
      _statusTitle = _isConnected
          ? "'$_currentLetter' harfini kameraya gösterin"
          : "Sunucu bağlantısı yok";
      _statusColor = _isConnected ? AppTheme.warmOrange : Colors.grey;
      _statusIcon = _isConnected ? Icons.front_hand_rounded : Icons.cloud_off;
    });
  }

  void _connectToServer() {
    _socketService.connect(_appState.serverUrl);

    _socketService.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (connected) {
          _statusTitle = "'$_currentLetter' harfini kameraya gösterin";
          _errorDetail = null;
          _statusColor = AppTheme.warmOrange;
          _statusIcon = Icons.front_hand_rounded;
        } else {
          _statusTitle = "Sunucu bağlantısı yok";
          _errorDetail = "Ayarlardan sunucu IP adresini kontrol edin.";
          _statusColor = Colors.grey;
          _statusIcon = Icons.cloud_off;
        }
      });
    });

    _socketService.predictionDetailStream.listen(_handlePredictionEvent);
  }

  void _handlePredictionEvent(PredictionEvent event) {
    if (!mounted) return;
    final guide = _appState.getGuide(_currentLetter);

    setState(() {
      // 1. El algılanmadıysa
      if (event.hands == 0) {
        _correctHoldSteps = 0;
        _showErrorBorder = false;
        _statusTitle = "El algılanamıyor...";
        _errorDetail =
            "Elinizi kamera çerçevesinin ortasında net görünecek şekilde tutun.";
        _statusColor = AppTheme.warmYellow;
        _statusIcon = Icons.pan_tool_alt_rounded;
        return;
      }

      // 2. El sayısı hedef harfin gerektirdiği el sayısıyla uyuşmuyorsa (Özel Hata Mesajı)
      if (event.hands != guide.handCount) {
        _correctHoldSteps = 0;
        _consecutiveWrongSteps++;
        _showErrorBorder = true;
        _statusTitle = "Hatalı Hareket! (El Sayısı Yanlış)";
        _errorDetail = guide.handCount == 2
            ? "'$_currentLetter' harfi ÇİFT EL (2 el) ile yapılır, şu an sadece 1 el algılandı!"
            : "'$_currentLetter' harfi TEK EL ile yapılır, ekranda 2 el algılandı!";
        _statusColor = AppTheme.warmRed;
        _statusIcon = Icons.warning_amber_rounded;

        if (_consecutiveWrongSteps >= 3) {
          _showTipBanner = true;
        }
        return;
      }

      // 3. Doğru harf algılandıysa (Sabit tutma sayacını artır)
      if (event.char == _currentLetter) {
        _consecutiveWrongSteps = 0;
        _showErrorBorder = false;
        if (_correctHoldSteps < _requiredHoldSteps) {
          _correctHoldSteps++;
        }

        if (_correctHoldSteps >= _requiredHoldSteps) {
          _isLetterCompleted = true;
          _statusTitle = "TEBRİKLER! '$_currentLetter' Harfi Doğru!";
          _errorDetail = "Harfi başarıyla tamamladınız.";
          _statusColor = AppTheme.successGreen;
          _statusIcon = Icons.verified_rounded;
          _appState.markLetterLearned(_currentLetter);
        } else {
          _statusTitle =
              "Doğru Pozisyon! Sabit Tutun ($_correctHoldSteps/$_requiredHoldSteps)";
          _errorDetail = "Harfin onaylanması için elinizi bozmadan tutun...";
          _statusColor = AppTheme.successGreen;
          _statusIcon = Icons.timelapse_rounded;
        }
        return;
      }

      // 4. El sayısı doğru ama hareket/parmak şekli yanlışsa (Hata Mesajı)
      _correctHoldSteps = 0;
      _consecutiveWrongSteps++;
      _showErrorBorder = true;

      if (event.char == "...") {
        _statusTitle = "Hareket Yanlış / Belirsiz!";
        _errorDetail =
            "Parmaklarınızın duruşu '$_currentLetter' harfiyle eşleşmiyor. İpucunu kontrol edin.";
      } else {
        _statusTitle = "Hatalı Hareket! ('${event.char}' Algılandı)";
        _errorDetail =
            "Yaptığınız hareket '${event.char}' harfine benziyor. Hedef: '$_currentLetter' harfi.";
      }
      _statusColor = AppTheme.warmRed;
      _statusIcon = Icons.error_outline_rounded;

      // Üst üste 3 kez yanlış yapılırsa ipucu kartını otomatik aç
      if (_consecutiveWrongSteps >= 3) {
        _showTipBanner = true;
      }
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

      await _controller?.dispose();
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (kIsWeb) {
        _webFrameTimer?.cancel();
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
          _statusTitle = "Kamera erişim hatası";
          _errorDetail = e.toString();
          _statusColor = AppTheme.warmRed;
        });
      }
    }
  }

  Future<void> _toggleCameraDirection() async {
    _appState.setUseFrontCamera(!_appState.useFrontCamera);
    await _initializeCamera();
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
                _statusTitle = "Yeniden bağlanılıyor...";
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
    super.dispose();
  }

  Widget _glassButton({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    Color? bgColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: padding ?? const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor ?? AppTheme.darkBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: child,
          ),
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
                'Kamera hazırlanıyor...',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final guide = _appState.getGuide(_currentLetter);
    final double holdProgress = _correctHoldSteps / _requiredHoldSteps;
    final int currentIdx = _currentLetterIndex;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // 1. KAMERA ÖNİZLEME
          SizedBox.expand(child: CameraPreview(_controller!)),

          // 2. BAŞARI VEYA HATA ÇERÇEVE EFEKTİ
          if (_isLetterCompleted || _showErrorBorder)
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (_isLetterCompleted
                            ? AppTheme.successGreen
                            : AppTheme.warmRed)
                        .withValues(alpha: 0.75),
                    width: 5,
                  ),
                ),
              ),
            ),

          // 3. ÜST BAR (Geri, Bağlantı Durumu, İpucu, Kamera Çevir, Sunucu Ayarı)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _glassButton(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                _glassButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const SizedBox(width: 6),
                      Text(
                        _isConnected ? "Canlı" : "Kopuk",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // İpucu Aç/Kapat Butonu
                _glassButton(
                  bgColor: _showTipBanner
                      ? AppTheme.warmOrange.withValues(alpha: 0.8)
                      : null,
                  onTap: () => setState(() => _showTipBanner = !_showTipBanner),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                // Ön / Arka Kamera Değiştirme Butonu
                _glassButton(
                  onTap: _toggleCameraDirection,
                  child: const Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                // Sunucu Ayarları
                _glassButton(
                  onTap: _showServerSettingsDialog,
                  child: const Icon(
                    Icons.settings_ethernet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // 4. HEDEF HARF VE DOĞRULAMA HALKASI (SAĞ ÜST)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 16,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'HEDEF (${guide.handCount} EL)',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: CircularProgressIndicator(
                            value: holdProgress > 0 ? holdProgress : 0.0,
                            strokeWidth: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.successGreen,
                            ),
                          ),
                        ),
                        Text(
                          _currentLetter,
                          style: GoogleFonts.poppins(
                            color: _isLetterCompleted
                                ? AppTheme.successGreen
                                : AppTheme.warmGold,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. AÇILIR/KAPANIR İPUCU KARTI (Üst Sol/Orta)
          if (_showTipBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 120,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.warmGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_rounded,
                          color: AppTheme.warmGold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$_currentLetter Harfi Nasıl Yapılır?',
                            style: GoogleFonts.poppins(
                              color: AppTheme.warmGold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _showTipBanner = false),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.tip,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. ALT DURUM / HATA MESAJI KARTI VE HARF GEZİNME BUTONLARI
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hata veya Başarı Bildirim Kutusu
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_statusIcon, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _statusTitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorDetail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _errorDetail!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Kameradan Çıkmadan Önceki / Sonraki Harfe Geçiş Çubuğu
                Row(
                  children: [
                    Expanded(
                      child: _glassButton(
                        onTap: currentIdx > 0
                            ? () => _changeTargetLetter(currentIdx - 1)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentIdx > 0
                                  ? 'Önceki (${LetterInfo.alphabets[currentIdx - 1]})'
                                  : 'İlk Harf',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _glassButton(
                        bgColor: _isLetterCompleted
                            ? AppTheme.successGreen.withValues(alpha: 0.85)
                            : null,
                        onTap: currentIdx < LetterInfo.alphabets.length - 1
                            ? () => _changeTargetLetter(currentIdx + 1)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentIdx < LetterInfo.alphabets.length - 1
                                  ? 'Sonraki (${LetterInfo.alphabets[currentIdx + 1]})'
                                  : 'Son Harf',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
