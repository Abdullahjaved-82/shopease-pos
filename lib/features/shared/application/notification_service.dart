import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:pos_system/core/repositories/customers_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;

  Future<void> sendReceipt({
    required Sale sale,
    required List<String> itemSummaries,
    required Customer? customer,
    required double balance,
  }) async {
    if (customer?.phone == null || customer!.phone!.isEmpty || sale.totalAmount <= 0) return;
    final settings = await _ref.read(shopSettingsControllerProvider.future);
    final message = _receiptMessage(settings, sale, customer, itemSummaries, balance);
    final phone = _formatPhone(customer.phone!);
    await _launchWithFallback(phone, message);
  }

  Future<void> sendBalanceReminder({required Customer customer, required double balance}) async {
    if (customer.phone == null || customer.phone!.isEmpty) return;
    final settings = await _ref.read(shopSettingsControllerProvider.future);
    final template = settings.balanceReminderTemplate;
    final message = _fillTemplate(
      template,
      {
        'shop': settings.name,
        'name': customer.name,
        'balance': balance.toStringAsFixed(2),
      },
    );
    final phone = _formatPhone(customer.phone!);
    await _launchWithFallback(phone, message);
  }

  Future<void> sendBulkBalanceReminders(List<CustomerWithBalance> customers) async {
    for (final item in customers.where((c) => c.balance > 0.01 && (c.customer.phone?.isNotEmpty ?? false))) {
      await sendBalanceReminder(customer: item.customer, balance: item.balance);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  String _receiptMessage(
    ShopSettings settings,
    Sale sale,
    Customer customer,
    List<String> itemSummaries,
    double balance,
  ) {
    final template = settings.receiptTemplate;
    final date = DateFormat('yyyy-MM-dd HH:mm').format(sale.createdAt);
    final itemsText = itemSummaries.join('\n');
    return _fillTemplate(
      template,
      {
        'shop': settings.name,
        'name': customer.name,
        'saleId': sale.id.toString(),
        'date': date,
        'items': itemsText,
        'total': sale.totalAmount.toStringAsFixed(2),
        'balance': balance.toStringAsFixed(2),
      },
    );
  }

  String _fillTemplate(String template, Map<String, String> values) {
    var result = template;
    values.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) return '+$digits';
    if (digits.startsWith('0') && digits.length > 1) return '+92${digits.substring(1)}';
    if (digits.startsWith('3') && digits.length == 10) return '+92$digits';
    return digits.startsWith('+') ? digits : '+$digits';
  }

  Future<void> _launchWithFallback(String phone, String message) async {
    final waUri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await _launchExternal(waUri)) return;
    final smsUri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    await _launchExternal(smsUri);
  }

  Future<bool> _launchExternal(Uri uri) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched;
    } catch (_) {
      return false;
    }
  }
}

