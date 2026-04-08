import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:socket_io_client/socket_io_client.dart' as io;

class PredictionEvent {
  final String char;
  final double confidence;
  final int hands;

  const PredictionEvent({
    required this.char,
    required this.confidence,
    required this.hands,
  });
}

/// Python sunucusuyla iletişimi yöneten WebSocket servis sınıfı
class SocketService {
  io.Socket? _socket;
  String? _lastPrediction;
  bool _isConnected = false;

  final StreamController<String> _predictionController =
      StreamController<String>.broadcast();
  final StreamController<PredictionEvent> _detailController =
      StreamController<PredictionEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<String> get predictionStream => _predictionController.stream;
  Stream<PredictionEvent> get predictionDetailStream => _detailController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;
  String? get lastPrediction => _lastPrediction;

  void connect(String serverUrl) {
    try {
      disconnect();
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      _socket!.onConnect((_) {
        _isConnected = true;
        if (!_connectionController.isClosed) {
          _connectionController.add(true);
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
      });

      _socket!.on('prediction_result', (data) {
        if (data != null && data['char'] != null) {
          final String charStr = data['char'].toString();
          final double conf = (data['confidence'] is num)
              ? (data['confidence'] as num).toDouble()
              : 0.0;
          final int hands = (data['hands'] is num)
              ? (data['hands'] as num).toInt()
              : 0;

          _lastPrediction = charStr;
          if (!_predictionController.isClosed) {
            _predictionController.add(charStr);
          }
          if (!_detailController.isClosed) {
            _detailController.add(
              PredictionEvent(char: charStr, confidence: conf, hands: hands),
            );
          }
        }
      });

      _socket!.connect();
    } catch (e) {
      _isConnected = false;
    }
  }

  void sendFrame(Uint8List jpegBytes) {
    if (_socket != null && _isConnected) {
      final String base64Image = base64Encode(jpegBytes);
      _socket!.emit('frame_data', {'image': base64Image});
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _predictionController.close();
    _detailController.close();
    _connectionController.close();
  }
}
