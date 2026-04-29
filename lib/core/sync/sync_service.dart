import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/sync/peer_discovery_service.dart';
import 'package:pos_system/core/sync/sync_change.dart';
import 'package:pos_system/core/sync/sync_client.dart';
import 'package:pos_system/core/sync/sync_log_repository.dart';
import 'package:pos_system/core/sync/sync_peer.dart';
import 'package:pos_system/core/sync/sync_server.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';

class SyncService {
  SyncService({
    required AppDatabase db,
    SyncLogRepository? syncLogRepository,
    SyncClient? syncClient,
    PeerDiscoveryService? discovery,
  })  : _db = db,
        _syncLog = syncLogRepository ?? SyncLogRepository(db),
        _client = syncClient ?? SyncClient(),
        _discovery = discovery ?? PeerDiscoveryService();

  final AppDatabase _db;
  final SyncLogRepository _syncLog;
  final SyncClient _client;
  final PeerDiscoveryService _discovery;

  SyncServer? _server;
  StreamSubscription<List<SyncPeer>>? _peerSub;
  final ValueNotifier<List<SyncPeer>> peers = ValueNotifier<List<SyncPeer>>(const []);

  DateTime? _lastSyncAt;
  bool _syncEnabled = false;
  bool _isMaster = false;
  String _deviceId = '';
  String _deviceName = '';
  String? _masterHost;

  Future<void> initialize({required Future<ShopSettings> Function() getSettings}) async {
    final settings = await getSettings();
    _syncEnabled = settings.syncEnabled;
    _isMaster = settings.syncIsMaster;
    _deviceId = settings.syncDeviceId;
    _deviceName = settings.syncDeviceName;
    _masterHost = settings.syncMasterHost;
    _lastSyncAt = settings.syncLastSyncAt;

    await _syncLog.ensureSchema();
    await _discovery.start();
    _peerSub ??= _discovery.peersStream.listen((list) {
      peers.value = list.where((p) => p.deviceId != _deviceId).toList(growable: false);
    });

    if (_syncEnabled) {
      await _startServerIfNeeded();
      await _discovery.announce(deviceId: _deviceId, deviceName: _deviceName);
    } else {
      await _stopServerIfNeeded();
    }
  }

  Future<void> refreshFromSettings(ShopSettings settings) async {
    _syncEnabled = settings.syncEnabled;
    _isMaster = settings.syncIsMaster;
    _deviceId = settings.syncDeviceId;
    _deviceName = settings.syncDeviceName;
    _masterHost = settings.syncMasterHost;
    _lastSyncAt = settings.syncLastSyncAt;
    if (_syncEnabled) {
      await _startServerIfNeeded();
      await _discovery.announce(deviceId: _deviceId, deviceName: _deviceName);
    } else {
      await _stopServerIfNeeded();
    }
  }

  Future<void> onAppResume({
    required Future<ShopSettings> Function() getSettings,
    required Future<void> Function(ShopSettings updated) saveSettings,
  }) async {
    final settings = await getSettings();
    await refreshFromSettings(settings);
    if (!_syncEnabled) return;
    await _discovery.announce(deviceId: _deviceId, deviceName: _deviceName);
    if (!_isMaster) {
      await syncNow(getSettings: getSettings, saveSettings: saveSettings);
    }
  }

  Future<void> syncNow({
    required Future<ShopSettings> Function() getSettings,
    required Future<void> Function(ShopSettings updated) saveSettings,
  }) async {
    final settings = await getSettings();
    if (!settings.syncEnabled) return;

    final target = await _resolveMasterPeer(settings);
    if (target == null) return;

    final pending = await _syncLog.pendingChanges();
    await _client.push(target, pending);
    await _syncLog.markSynced(pending.map((e) => e.id));

    final pulled = await _client.pull(target, since: settings.syncLastSyncAt);
    await applyRemoteChanges(pulled);

    final now = DateTime.now().toUtc();
    _lastSyncAt = now;
    await saveSettings(settings.copyWith(syncLastSyncAt: now));
  }

  Future<Map<String, dynamic>> status() async {
    return {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'lastSyncAt': _lastSyncAt?.toIso8601String(),
      'pendingChanges': await _syncLog.pendingCount(),
    };
  }

  Future<List<Map<String, dynamic>>> pull(DateTime? since) async {
    final changes = await _syncLog.pullSince(since);
    return changes.map((e) => e.toJson()).toList(growable: false);
  }

  Future<void> push(List<Map<String, dynamic>> payload) async {
    final changes = payload.map(SyncChange.fromJson).toList(growable: false);
    await applyRemoteChanges(changes);
  }

  Future<void> applyRemoteChanges(List<SyncChange> changes) async {
    if (changes.isEmpty) return;
    await _db.transaction(() async {
      for (final change in changes) {
        if (change.deviceId == _deviceId) continue;
        switch (change.tableName) {
          case 'products':
            await _applyProductChange(change);
            break;
          case 'customers':
            await _applyCustomerChange(change);
            break;
          case 'sales':
            await _applySaleChange(change);
            break;
        }
        await _syncLog.appendChange(
          tableName: change.tableName,
          recordId: change.recordId,
          operation: change.operation,
          data: change.data,
          deviceId: change.deviceId,
          changedAt: change.changedAt,
          changeId: change.id,
        );
        await _syncLog.markSynced([change.id], at: DateTime.now().toUtc());
      }
    });
  }

  Stream<List<SyncChange>> watchLogs() => _syncLog.watchRecent();

  Future<void> dispose() async {
    await _peerSub?.cancel();
    await _stopServerIfNeeded();
    await _discovery.stop();
    _client.dispose();
    peers.dispose();
  }

  Future<void> _startServerIfNeeded() async {
    _server ??= SyncServer(
      handlerStatus: status,
      handlerPush: push,
      handlerPull: pull,
    );
    await _server!.start();
  }

  Future<void> _stopServerIfNeeded() async {
    await _server?.stop();
    _server = null;
  }

  Future<SyncPeer?> _resolveMasterPeer(ShopSettings settings) async {
    if (settings.syncIsMaster) return null;

    if (settings.syncMasterHost != null && settings.syncMasterHost!.isNotEmpty) {
      return SyncPeer(
        deviceId: 'master',
        deviceName: 'Master Register',
        ip: settings.syncMasterHost!,
        port: 7788,
        lastSeenAt: DateTime.now().toUtc(),
      );
    }

    final known = peers.value;
    if (known.isNotEmpty) {
      return known.first;
    }
    return null;
  }

  Future<void> _applyProductChange(SyncChange change) async {
    final id = int.tryParse(change.recordId);
    if (id == null) return;
    if (change.operation == 'delete') {
      await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
      return;
    }

    final incoming = change.data;
    final incomingUpdatedAt = _readDate(incoming['updatedAt']) ?? change.changedAt;
    final existing = await (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null && !incomingUpdatedAt.isAfter(existing.updatedAt.toUtc())) {
      return;
    }

    final companion = ProductsCompanion.insert(
      name: _asString(incoming['name']),
      barcode: Value(_asNullableString(incoming['barcode'])),
      categoryId: Value(_asNullableInt(incoming['categoryId'])),
      unit: Value(_asString(incoming['unit'], fallback: 'pcs')),
      reorderLevel: Value(_asInt(incoming['reorderLevel'])),
      costPrice: Value(_asDouble(incoming['costPrice'])),
      salePrice: Value(_asDouble(incoming['salePrice'])),
      stockQuantity: Value(_asInt(incoming['stockQuantity'])),
      isActive: Value(_asBool(incoming['isActive'], fallback: true)),
      createdAt: Value(_readDate(incoming['createdAt']) ?? DateTime.now().toUtc()),
      updatedAt: Value(incomingUpdatedAt),
    ).copyWith(id: Value(id));

    await _db.into(_db.products).insertOnConflictUpdate(companion);
  }

  Future<void> _applyCustomerChange(SyncChange change) async {
    final id = int.tryParse(change.recordId);
    if (id == null) return;
    if (change.operation == 'delete') {
      await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
      return;
    }

    final incoming = change.data;
    final incomingUpdatedAt = _readDate(incoming['_updatedAt']) ?? _readDate(incoming['createdAt']) ?? change.changedAt;
    final existing = await (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      final existingAt = existing.createdAt.toUtc();
      if (!incomingUpdatedAt.isAfter(existingAt)) {
        return;
      }
    }

    final companion = CustomersCompanion.insert(
      name: _asString(incoming['name']),
      phone: Value(_asNullableString(incoming['phone'])),
      cnic: Value(_asNullableString(incoming['cnic'])),
      email: Value(_asNullableString(incoming['email'])),
      address: Value(_asNullableString(incoming['address'])),
      creditLimit: Value(_asDouble(incoming['creditLimit'])),
      openingBalance: Value(_asDouble(incoming['openingBalance'])),
      currentBalance: Value(_asDouble(incoming['currentBalance'])),
      createdAt: Value(_readDate(incoming['createdAt']) ?? DateTime.now().toUtc()),
    ).copyWith(id: Value(id));

    await _db.into(_db.customers).insertOnConflictUpdate(companion);
  }

  Future<void> _applySaleChange(SyncChange change) async {
    final id = int.tryParse(change.recordId);
    if (id == null) return;
    if (change.operation != 'insert') {
      return;
    }

    final existing = await (_db.select(_db.sales)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) return;

    final incoming = change.data;
    final companion = SalesCompanion.insert(
      customerId: Value(_asNullableInt(incoming['customerId'])),
      totalAmount: _asDouble(incoming['totalAmount']),
      discount: Value(_asDouble(incoming['discount'])),
      paymentMethod: Value(_asString(incoming['paymentMethod'], fallback: 'cash')),
      paidAmount: Value(_asDouble(incoming['paidAmount'])),
      changeAmount: Value(_asDouble(incoming['changeAmount'])),
      userId: _asInt(incoming['userId']),
      note: Value(_asNullableString(incoming['note'])),
      createdAt: Value(_readDate(incoming['createdAt']) ?? DateTime.now().toUtc()),
    ).copyWith(id: Value(id));

    await _db.into(_db.sales).insert(companion);
  }

  DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final parsed = DateTime.tryParse('$value');
    return parsed?.toUtc();
  }

  String _asString(Object? value, {String fallback = ''}) {
    final text = '$value';
    if (value == null || text == 'null') return fallback;
    return text;
  }

  String? _asNullableString(Object? value) {
    if (value == null) return null;
    final text = '$value';
    return text == 'null' || text.isEmpty ? null : text;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return fallback;
  }
}

