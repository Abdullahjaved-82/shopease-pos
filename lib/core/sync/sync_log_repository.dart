import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/sync/sync_change.dart';

class SyncLogRepository {
  SyncLogRepository(this._db);

  final AppDatabase _db;
  final Random _random = Random();
   Future<void>? _schemaReady;

  Future<void> _ensureSchemaReady() {
    return _schemaReady ??= ensureSchema();
  }

  Future<void> ensureSchema() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        synced_at INTEGER,
        device_id TEXT NOT NULL,
        changed_at INTEGER NOT NULL
      );
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_log_changed_at ON sync_log(changed_at);',
    );
  }

  String newChangeId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16);
    return '${now}_$rand';
  }

  Future<void> appendChange({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
    required String deviceId,
    DateTime? changedAt,
    String? changeId,
  }) async {
    await _ensureSchemaReady();
    final at = (changedAt ?? DateTime.now().toUtc()).toUtc();
    final id = changeId ?? newChangeId();
    await _db.customStatement(
      '''
      INSERT OR REPLACE INTO sync_log (id, table_name, record_id, operation, data, synced_at, device_id, changed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        tableName,
        recordId,
        operation,
        jsonEncode(data),
        null,
        deviceId,
        at.millisecondsSinceEpoch,
      ],
    );
  }

  Future<int> pendingCount() async {
    await _ensureSchemaReady();
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM sync_log WHERE synced_at IS NULL',
      readsFrom: {},
    ).getSingle();
    return (row.data['c'] as int?) ?? 0;
  }

  Future<List<SyncChange>> pullSince(DateTime? since) async {
    await _ensureSchemaReady();
    final sql = StringBuffer('SELECT * FROM sync_log');
    final vars = <Variable<Object>>[];
    if (since != null) {
      sql.write(' WHERE changed_at > ?');
      vars.add(Variable<int>(since.toUtc().millisecondsSinceEpoch));
    }
    sql.write(' ORDER BY changed_at ASC');
    final rows = await _db.customSelect(sql.toString(), variables: vars, readsFrom: {}).get();
    return rows.map(_rowToChange).toList(growable: false);
  }

  Future<List<SyncChange>> pendingChanges() async {
    await _ensureSchemaReady();
    final rows = await _db.customSelect(
      'SELECT * FROM sync_log WHERE synced_at IS NULL ORDER BY changed_at ASC',
      readsFrom: {},
    ).get();
    return rows.map(_rowToChange).toList(growable: false);
  }

  Future<void> markSynced(Iterable<String> ids, {DateTime? at}) async {
    await _ensureSchemaReady();
    final list = ids.toList(growable: false);
    if (list.isEmpty) return;
    final syncedAt = (at ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final placeholders = List.filled(list.length, '?').join(',');
    await _db.customStatement(
      'UPDATE sync_log SET synced_at = ? WHERE id IN ($placeholders)',
      [syncedAt, ...list],
    );
  }

  Stream<List<SyncChange>> watchRecent({int limit = 200}) {
    return Stream.fromFuture(_ensureSchemaReady()).asyncExpand((_) {
      final query = _db.customSelect(
        'SELECT * FROM sync_log ORDER BY changed_at DESC LIMIT $limit',
        readsFrom: {},
      );
      return query.watch().map((rows) => rows.map(_rowToChange).toList(growable: false));
    });
  }

  SyncChange _rowToChange(QueryRow row) {
    final dataRaw = row.data['data'] as String? ?? '{}';
    return SyncChange(
      id: '${row.data['id']}',
      tableName: '${row.data['table_name']}',
      recordId: '${row.data['record_id']}',
      operation: '${row.data['operation']}',
      data: Map<String, dynamic>.from(jsonDecode(dataRaw) as Map),
      deviceId: '${row.data['device_id']}',
      changedAt: DateTime.fromMillisecondsSinceEpoch((row.data['changed_at'] as int?) ?? 0, isUtc: true),
      syncedAt: row.data['synced_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.data['synced_at'] as int, isUtc: true),
    );
  }
}

