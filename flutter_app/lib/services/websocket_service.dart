import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String _wsUrl = 'wss://flowlens-api-service.onrender.com/ws';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _prStateController = StreamController<PRStateUpdate>.broadcast();
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // Stream for PR state updates
  Stream<PRStateUpdate> get prStateUpdates => _prStateController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String);

      // Parse minimal PR state update
      final update = PRStateUpdate(
        repositoryId: data['repo_id'] as String,
        prNumber: data['pr_number'] as int,
        state: data['state'] as String,
      );

      _prStateController.add(update);
    } catch (e) {
      // Error parsing WebSocket message
    }
  }

  void _onError(error) {
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDisconnected() {
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _prStateController.close();
  }
}

class PRStateUpdate {
  final String repositoryId;
  final int prNumber;
  final String state;

  PRStateUpdate({
    required this.repositoryId,
    required this.prNumber,
    required this.state,
  });

  @override
  String toString() {
    return 'PRStateUpdate(repositoryId: $repositoryId, prNumber: $prNumber, state: $state)';
  }
}
