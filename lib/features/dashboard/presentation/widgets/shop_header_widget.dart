import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/sales/application/shift_guard.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';

class ShopHeaderWidget extends ConsumerWidget {
  const ShopHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(shopSettingsProvider);
    final shiftAsync = ref.watch(currentShiftProvider);
    final money = NumberFormat('#,##0.00');

    final settings = settingsAsync.value;
    final adminName = (settings?.adminName.trim().isNotEmpty ?? false)
        ? settings!.adminName.trim()
        : 'Admin';
    final shopName = (settings?.name.trim().isNotEmpty ?? false)
        ? settings!.name.trim()
        : 'ShopEase';
    final shopCity = (settings?.shopCity.trim().isNotEmpty ?? false)
        ? settings!.shopCity.trim()
        : _cityFromAddress(settings?.address ?? '');
    final fbrEnabled = settings?.fbrEnabled ?? false;

    final shift = shiftAsync.valueOrNull;
    final shiftLabel = shift == null
        ? 'Shift Closed'
        : 'Shift Open · PKR ${money.format(shift.openingCash)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: pkGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assalam-o-Alaikum, $adminName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$shopName · $shopCity',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: pkGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _pill(
                label: fbrEnabled ? 'FBR Active' : 'FBR Off',
                background: fbrEnabled ? pkGreenLight : pkGold,
                foreground: fbrEnabled ? Colors.white : pkGreen,
              ),
              _pill(
                label: shiftLabel,
                background: pkGold,
                foreground: pkGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _cityFromAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return 'Pakistan';
    final parts = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Pakistan';
    return parts.length == 1 ? parts.first : parts.last;
  }
}

