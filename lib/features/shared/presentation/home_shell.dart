import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/inventory/application/low_stock_provider.dart';
import 'package:pos_system/features/invoices/application/overdue_invoices_provider.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/l10n/app_localizations.dart';

final udharCustomersCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(customersRepositoryProvider);
  return repo.watchWithBalance(onlyWithBalance: true).map((rows) => rows.length);
});

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with SingleTickerProviderStateMixin {
  late final AnimationController _lowStockPulseController;

  @override
  void initState() {
    super.initState();
    _lowStockPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.4,
      upperBound: 1,
    );
    _lowStockPulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _lowStockPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final lowStockCount = ref.watch(lowStockCountProvider).maybeWhen(data: (v) => v, orElse: () => 0);
    final overdueCount = ref.watch(overdueInvoicesProvider).maybeWhen(data: (list) => list.length, orElse: () => 0);
    final udharCount = ref.watch(udharCustomersCountProvider).maybeWhen(data: (v) => v, orElse: () => 0);

    final appLocalizations = AppLocalizations.of(context);
    final destinations = <_Destination>[
      _Destination(label: 'Dashboard', icon: Icons.dashboard_outlined, section: _NavSection.main, adminOnly: true),
      _Destination(label: appLocalizations.sales, icon: Icons.point_of_sale_outlined, section: _NavSection.main),
      _Destination(label: appLocalizations.products, icon: Icons.inventory_2_outlined, section: _NavSection.catalog),
      _Destination(
        label: appLocalizations.inventory,
        icon: Icons.warehouse_outlined,
        section: _NavSection.catalog,
        badgeCount: lowStockCount > 0 ? lowStockCount : null,
        badgeColor: pkRed,
        pulseBadge: true,
      ),
      _Destination(
        label: appLocalizations.customers,
        icon: Icons.people_alt_outlined,
        section: _NavSection.catalog,
        badgeCount: udharCount > 0 ? udharCount : null,
        badgeColor: pkGold,
      ),
      _Destination(
        label: 'Invoices',
        icon: Icons.receipt_long_outlined,
        section: _NavSection.finance,
        badgeCount: overdueCount > 0 ? overdueCount : null,
        badgeColor: pkGold,
      ),
      _Destination(label: appLocalizations.reports, icon: Icons.bar_chart_outlined, section: _NavSection.finance, adminOnly: true),
      _Destination(label: 'Settings', icon: Icons.settings, section: _NavSection.finance, adminOnly: true),
    ];

    void onDestinationSelected(int index) {
      final dest = destinations[index];
      if (dest.adminOnly && auth.role != UserRole.admin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin only')));
        return;
      }
      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
    }

    final roleLabel = auth.role == UserRole.admin ? 'Admin' : 'Cashier';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 220,
                  color: pkGreen,
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: _ShopRailHeader(),
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel(title: 'MAIN'),
                                ..._buildSection(destinations, _NavSection.main, widget.navigationShell.currentIndex, onDestinationSelected),
                                _SectionLabel(title: 'CATALOG'),
                                ..._buildSection(destinations, _NavSection.catalog, widget.navigationShell.currentIndex, onDestinationSelected),
                                _SectionLabel(title: 'FINANCE'),
                                ..._buildSection(destinations, _NavSection.finance, widget.navigationShell.currentIndex, onDestinationSelected),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: _UserFooter(name: auth.userName ?? 'User', role: roleLabel),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: IconButton(
                            tooltip: 'Logout',
                            icon: const Icon(Icons.logout, color: Colors.white70),
                            onPressed: () {
                              ref.read(authControllerProvider.notifier).logout();
                              context.go('/login');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _shellBody()),
              ],
            ),
          );
        }

        final current = destinations[widget.navigationShell.currentIndex];
        return Scaffold(
          body: _shellBody(),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: pkGreen,
            selectedItemColor: pkGold,
            unselectedItemColor: Colors.white54,
            showUnselectedLabels: false,
            showSelectedLabels: true,
            currentIndex: widget.navigationShell.currentIndex,
            onTap: onDestinationSelected,
            items: [
              for (final d in destinations)
                BottomNavigationBarItem(
                  icon: d.showBadge
                      ? Badge(
                          backgroundColor: d.badgeColor,
                          label: d.badgeCount == null ? null : Text('${d.badgeCount}'),
                          child: Icon(d.icon),
                        )
                      : Icon(d.icon),
                  label: d == current ? d.label : '',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _shellBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<int>(widget.navigationShell.currentIndex),
        child: widget.navigationShell,
      ),
    );
  }

  List<Widget> _buildSection(
    List<_Destination> destinations,
    _NavSection section,
    int selectedIndex,
    ValueChanged<int> onTap,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.section != section) continue;
      widgets.add(
        _SidebarNavItem(
          destination: d,
          lowStockPulse: d.pulseBadge ? _lowStockPulseController : null,
          selected: i == selectedIndex,
          onTap: () => onTap(i),
        ),
      );
    }
    return widgets;
  }
}

class _ShopRailHeader extends ConsumerWidget {
  const _ShopRailHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value;
    final shopName = (settings?.name.trim().isNotEmpty ?? false) ? settings!.name.trim() : 'ShopEase';
    final shopCity = (settings?.shopCity.trim().isNotEmpty ?? false)
        ? settings!.shopCity.trim()
        : _cityFromAddress(settings?.address ?? 'Pakistan');

    final logoPath = settings?.logoPath;
    final logoFile = (logoPath != null && logoPath.isNotEmpty) ? File(logoPath) : null;
    final hasLogo = logoFile?.existsSync() ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hasLogo
            ? ClipOval(
                child: Image.file(
                  logoFile!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : CircleAvatar(
                radius: 20,
                backgroundColor: pkGold,
                foregroundColor: pkGreen,
                child: Text(
                  _initials(shopName),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
        const SizedBox(height: 10),
        Text(
          shopName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          shopCity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(color: pkGold, borderRadius: BorderRadius.circular(10)),
        ),
      ],
    );
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (words.isEmpty) return 'SE';
    if (words.length == 1) return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  String _cityFromAddress(String address) {
    final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Pakistan';
    return parts.length == 1 ? parts.first : parts.last;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          letterSpacing: 0.08,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.destination,
    required this.lowStockPulse,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final AnimationController? lowStockPulse;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? pkGold : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? pkGold.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? pkGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(destination.icon, size: 20, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(fontSize: 13, color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (destination.showBadge)
                  FadeTransition(
                    opacity: destination.badgeColor == pkRed && lowStockPulse != null ? lowStockPulse! : const AlwaysStoppedAnimation<double>(1),
                    child: Badge(
                      backgroundColor: destination.badgeColor,
                      textColor: destination.badgeColor == pkRed ? Colors.white : pkGreen,
                      label: Text('${destination.badgeCount}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'U'
        : name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join().toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: pkGold,
          foregroundColor: pkGreen,
          child: Text(initials),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text(role, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _NavSection { main, catalog, finance }

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.section,
    this.badgeCount,
    this.badgeColor = pkGold,
    this.pulseBadge = false,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;
  final _NavSection section;
  final int? badgeCount;
  final Color badgeColor;
  final bool pulseBadge;
  final bool adminOnly;

  bool get showBadge => badgeCount != null;
}
