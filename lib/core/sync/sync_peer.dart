class SyncPeer {
  const SyncPeer({
    required this.deviceId,
    required this.deviceName,
    required this.ip,
    required this.port,
    required this.lastSeenAt,
    this.lastSyncAt,
  });

  final String deviceId;
  final String deviceName;
  final String ip;
  final int port;
  final DateTime lastSeenAt;
  final DateTime? lastSyncAt;

  SyncPeer copyWith({DateTime? lastSeenAt, DateTime? lastSyncAt}) {
    return SyncPeer(
      deviceId: deviceId,
      deviceName: deviceName,
      ip: ip,
      port: port,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

