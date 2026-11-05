import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Python sunucusuyla iletişimi yöneten servis sınıfı
class SocketService {
  IO.Socket? _socket;
  String? _lastPrediction;
  bool _isConnected = false;
  bool _isCollecting = false;
  int _collectedCount = 0;

  final StreamController<String> _predictionController =
      StreamController<String>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _collectionController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<String> get predictionStream => _predictionController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get collectionStream =>
      _collectionController.stream;

  bool get isConnected => _isConnected;
  bool get isCollecting => _isCollecting;
  int get collectedCount => _collectedCount;
  String? get lastPrediction => _lastPrediction;

  void connect(String serverUrl) {
    try {
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      _socket!.onConnect((_) {
        print('✅ Sunucuya bağlandı!');
        _isConnected = true;
        _connectionController.add(true);
      });

      _socket!.onDisconnect((_) {
        print('❌ Sunucu bağlantısı kesildi');
        _isConnected = false;
        _connectionController.add(false);
      });

      _socket!.onConnectError((error) {
        print('⚠️ Bağlantı hatası: $error');
        _isConnected = false;
        _connectionController.add(false);
      });

      // Tahmin sonucu
      _socket!.on('prediction_result', (data) {
        if (data != null && data['char'] != null) {
          _lastPrediction = data['char'];
          _predictionController.add(data['char']);
        }
      });

      // Veri toplama durumu
      _socket!.on('collection_status', (data) {
        if (data != null) {
          String status = data['status'] ?? '';
          if (status == 'started') {
            _isCollecting = true;
            _collectedCount = 0;
          } else if (status == 'stopped') {
            _isCollecting = false;
          } else if (status == 'saved') {
            _collectedCount = data['count'] ?? 0;
          }
          _collectionController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.connect();
    } catch (e) {
      print('Socket bağlantı hatası: $e');
    }
  }

  /// Veri toplama modunu başlat
  void startCollection(String letter) {
    if (_socket != null && _isConnected) {
      _socket!.emit('start_collection', {'letter': letter});
    }
  }

  /// Veri toplama modunu durdur
  void stopCollection() {
    if (_socket != null && _isConnected) {
      _socket!.emit('stop_collection');
    }
  }

  /// Kamera görüntüsünü gönder
  void sendFrame(Uint8List jpegBytes) {
    if (_socket != null && _isConnected) {
      String base64Image = base64Encode(jpegBytes);
      _socket!.emit('frame_data', {'image': base64Image});
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isCollecting = false;
  }

  void dispose() {
    disconnect();
    _predictionController.close();
    _connectionController.close();
    _collectionController.close();
  }
}
