import 'dart:convert';

class SyncChange {
  const SyncChange({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.data,
    required this.deviceId,
    required this.changedAt,
    this.syncedAt,
  });

  final String id;
  final String tableName;
  final String recordId;
  final String operation;
  final Map<String, dynamic> data;
  final String deviceId;
  final DateTime changedAt;
  final DateTime? syncedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableName': tableName,
        'recordId': recordId,
        'operation': operation,
        'data': data,
        'deviceId': deviceId,
        'changedAt': changedAt.toIso8601String(),
        'syncedAt': syncedAt?.toIso8601String(),
      };

  factory SyncChange.fromJson(Map<String, dynamic> json) {
    final payload = json['data'];
    return SyncChange(
      id: '${json['id']}',
      tableName: '${json['tableName']}',
      recordId: '${json['recordId']}',
      operation: '${json['operation']}',
      data: payload is Map<String, dynamic>
          ? payload
          : payload is String
              ? Map<String, dynamic>.from(jsonDecode(payload) as Map)
              : const {},
      deviceId: '${json['deviceId']}',
      changedAt: DateTime.parse('${json['changedAt']}').toUtc(),
      syncedAt: json['syncedAt'] == null ? null : DateTime.parse('${json['syncedAt']}').toUtc(),
    );
  }
}

