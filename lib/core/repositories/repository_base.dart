import 'package:pos_system/core/sync/sync_log_repository.dart';

abstract class RepositoryBase {
  RepositoryBase(this.syncLogRepository, this.deviceId);

  final SyncLogRepository syncLogRepository;
  final String deviceId;

  Future<void> logInsert({
    required String tableName,
    required Object recordId,
    required Map<String, dynamic> data,
  }) {
    return syncLogRepository.appendChange(
      tableName: tableName,
      recordId: '$recordId',
      operation: 'insert',
      data: data,
      deviceId: deviceId,
    );
  }

  Future<void> logUpdate({
    required String tableName,
    required Object recordId,
    required Map<String, dynamic> data,
  }) {
    return syncLogRepository.appendChange(
      tableName: tableName,
      recordId: '$recordId',
      operation: 'update',
      data: data,
      deviceId: deviceId,
    );
  }

  Future<void> logDelete({
    required String tableName,
    required Object recordId,
  }) {
    return syncLogRepository.appendChange(
      tableName: tableName,
      recordId: '$recordId',
      operation: 'delete',
      data: {'id': recordId},
      deviceId: deviceId,
    );
  }
}

