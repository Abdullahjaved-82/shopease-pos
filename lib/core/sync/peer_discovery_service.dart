import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pos_system/core/sync/sync_peer.dart';

class PeerDiscoveryService {
  PeerDiscoveryService({this.broadcastPort = 7789, this.serverPort = 7788});

  static const _helloPrefix = 'SHOPEASE_SYNC_HELLO';

  final int broadcastPort;
  final int serverPort;
  final _peers = <String, SyncPeer>{};
  final _controller = StreamController<List<SyncPeer>>.broadcast();

  RawDatagramSocket? _socket;

  Stream<List<SyncPeer>> get peersStream => _controller.stream;

  List<SyncPeer> get peers => _peers.values.toList(growable: false)
    ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

  Future<void> start() async {
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort, reuseAddress: true, reusePort: true);
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      _handleDatagram(datagram);
    });
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _peers.clear();
    _controller.add(const []);
  }

  Future<void> announce({required String deviceId, required String deviceName}) async {
    await start();
    final msg = jsonEncode({
      'type': _helloPrefix,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'port': serverPort,
      'time': DateTime.now().toUtc().toIso8601String(),
    });
    _socket?.send(utf8.encode(msg), InternetAddress('255.255.255.255'), broadcastPort);
  }

  void _handleDatagram(Datagram d) {
    final raw = utf8.decode(d.data, allowMalformed: true);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    if (decoded['type'] != _helloPrefix) return;
    final deviceId = '${decoded['deviceId'] ?? ''}';
    final deviceName = '${decoded['deviceName'] ?? ''}';
    final port = (decoded['port'] as num?)?.toInt() ?? serverPort;
    if (deviceId.isEmpty) return;
    _peers[deviceId] = SyncPeer(
      deviceId: deviceId,
      deviceName: deviceName.isEmpty ? 'Unknown Register' : deviceName,
      ip: d.address.address,
      port: port,
      lastSeenAt: DateTime.now().toUtc(),
    );
    _controller.add(peers);
  }
}

