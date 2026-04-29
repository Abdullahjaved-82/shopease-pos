import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pos_system/core/providers/repositories.dart';

class InvoiceOverdueNotificationService {
  InvoiceOverdueNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  DateTime? _lastNotifiedDate;

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    // Check every 15 minutes; only notifies once when local hour reaches 9.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _maybeNotify());
    await _maybeNotify();
  }

  Future<void> _maybeNotify() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (now.hour != 9) return;
    if (_lastNotifiedDate == today) return;

    final summary = await _ref.read(invoiceRepositoryProvider).watchOverdueSummary().first;
    if (summary.count <= 0) return;

    await _plugin.show(
      9001,
      'Overdue invoices alert',
      '${summary.count} invoices overdue - PKR ${summary.totalAmount.toStringAsFixed(2)} pending',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'overdue_invoices_channel',
          'Overdue Invoices',
          channelDescription: 'Daily overdue invoice reminder at 9am',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    _lastNotifiedDate = today;
  }

  void dispose() {
    _timer?.cancel();
  }
}

final invoiceOverdueNotificationServiceProvider = Provider<InvoiceOverdueNotificationService>((ref) {
  final service = InvoiceOverdueNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

