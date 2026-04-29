import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/customers_repository.dart';
import 'package:pos_system/core/repositories/products_repository.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/sales/application/cart_notifier.dart';
import 'package:pos_system/features/sales/application/shift_guard.dart';
import 'package:pos_system/features/settings/application/shop_settings_controller.dart';
import 'package:pos_system/features/settings/domain/shop_settings.dart';
import 'package:shimmer/shimmer.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orderDiscountController =
  TextEditingController();
  final TextEditingController _amountTenderedController =
  TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _debounce;
  String _search = '';
  int? _categoryId;
  bool _isCharging = false;
  int? _customerId;
  bool _promptedShift = false;
  int _loyaltyBalance = 0;
  int _redeemPoints = 0;
  double _loyaltySavings = 0;
  bool _redeemSelected = false;
  final GlobalKey _cartBadgeKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    _orderDiscountController.dispose();
    _amountTenderedController.dispose();
    _audioPlayer.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsRepo = ref.watch(productsRepositoryProvider);
    final customersRepo = ref.watch(customersRepositoryProvider);
    final cartState = ref.watch(cartNotifierProvider);
    final shiftAsync = ref.watch(currentShiftProvider);
    final shift = shiftAsync.valueOrNull;
    final auth = ref.watch(authControllerProvider);
    final settingsAsync = ref.watch(shopSettingsControllerProvider);
    final settings =
    settingsAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    _orderDiscountController.value = TextEditingValue(
        text: cartState.orderDiscountPercent.toStringAsFixed(0));
    _amountTenderedController.value = TextEditingValue(
        text: cartState.amountTendered == 0
            ? ''
            : cartState.amountTendered.toStringAsFixed(2));

    // FIX: use shiftAsync.valueOrNull == null instead of shift == null
    // to avoid the "operand can't be null, condition is always false" warning
    if (!_promptedShift &&
        auth.userId != null &&
        shiftAsync.valueOrNull == null &&
        shiftAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          _promptedShift = true;
          await ref.shiftGuard.ensureOpenShift(context);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          if (shift != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                  child: Text(
                      'Shift #${shift.id} · ${TimeOfDay.fromDateTime(shift.openedAt).format(context)}')),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('No open shift')),
            ),
          IconButton(
            icon: const Icon(Icons.attach_money),
            tooltip: 'Cash in/out',
            onPressed: () =>
                ref.shiftGuard.addMovement(context, type: 'in'),
          ),
          IconButton(
            icon: const Icon(Icons.money_off),
            tooltip: 'Cash out',
            onPressed: () =>
                ref.shiftGuard.addMovement(context, type: 'out'),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Close shift',
            onPressed: () async {
              await ref.shiftGuard.closeShift(context);
              setState(() => _promptedShift = false);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: isDesktop
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _ProductsPanel(
                productsRepo: productsRepo,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onProductAdded: _showAddToCartFly,
                search: _search,
                selectedCategoryId: _categoryId,
                onSelectCategory: (id) =>
                    setState(() => _categoryId = id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _CartPanel(
                isCharging: _isCharging,
                orderDiscountController: _orderDiscountController,
                amountTenderedController: _amountTenderedController,
                customersRepo: customersRepo,
                selectedCustomerId: _customerId,
                onSelectCustomer: (id) {
                  setState(() {
                    _customerId = id;
                    _redeemSelected = false;
                    _redeemPoints = 0;
                    _loyaltySavings = 0;
                  });
                  ref
                      .read(cartNotifierProvider.notifier)
                      .setCustomer(id);
                  _loadLoyaltyBalance(id);
                },
                onCharge: _onCharge,
                cartBadgeKey: _cartBadgeKey,
                loyaltyBalance: _loyaltyBalance,
                redeemPoints: _redeemPoints,
                loyaltySavings: _loyaltySavings,
                redeemSelected: _redeemSelected,
                settings: settings,
                onToggleRedeem: (selected, points, savings) {
                  setState(() {
                    _redeemSelected = selected;
                    _redeemPoints = points;
                    _loyaltySavings = savings;
                  });
                  ref
                      .read(cartNotifierProvider.notifier)
                      .applyLoyalty(points: points, discount: savings);
                },
              ),
            ),
          ],
        )
            : Column(
          children: [
            Expanded(
              flex: 5,
              child: _ProductsPanel(
                productsRepo: productsRepo,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onProductAdded: _showAddToCartFly,
                search: _search,
                selectedCategoryId: _categoryId,
                onSelectCategory: (id) =>
                    setState(() => _categoryId = id),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 6,
              child: _CartPanel(
                isCharging: _isCharging,
                orderDiscountController: _orderDiscountController,
                amountTenderedController: _amountTenderedController,
                customersRepo: customersRepo,
                selectedCustomerId: _customerId,
                onSelectCustomer: (id) {
                  setState(() {
                    _customerId = id;
                    _redeemSelected = false;
                    _redeemPoints = 0;
                    _loyaltySavings = 0;
                  });
                  ref
                      .read(cartNotifierProvider.notifier)
                      .setCustomer(id);
                  _loadLoyaltyBalance(id);
                },
                onCharge: _onCharge,
                cartBadgeKey: _cartBadgeKey,
                loyaltyBalance: _loyaltyBalance,
                redeemPoints: _redeemPoints,
                loyaltySavings: _loyaltySavings,
                redeemSelected: _redeemSelected,
                settings: settings,
                onToggleRedeem: (selected, points, savings) {
                  setState(() {
                    _redeemSelected = selected;
                    _redeemPoints = points;
                    _loyaltySavings = savings;
                  });
                  ref
                      .read(cartNotifierProvider.notifier)
                      .applyLoyalty(points: points, discount: savings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _search = value.trim());
    });
  }

  Future<void> _playChargeSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/charge_ding.wav'));
    } catch (_) {
      // Ignore audio errors so checkout flow is never blocked.
    }
  }

  Future<void> _onCharge() async {
    final settings = await ref.read(shopSettingsControllerProvider.future);
    final cart = ref.read(cartNotifierProvider);
    final chargedAmount = cart.total;
    final expectedEarn = cart.customerId != null
        ? (cart.total * settings.pointsPerRupee).floor()
        : 0;

    final auth = ref.read(authControllerProvider);
    final shift = ref.read(currentShiftProvider).valueOrNull;
    if (shift == null) {
      if (auth.role == UserRole.admin) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No open shift'),
            content: const Text(
                'Open a shift or proceed with admin override?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Open shift')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Override')),
            ],
          ),
        );
        if (proceed != true) {
          await ref.shiftGuard.ensureOpenShift(context);
          return;
        }
      } else {
        await ref.shiftGuard.ensureOpenShift(context);
        return;
      }
    }

    setState(() => _isCharging = true);
    final notifier = ref.read(cartNotifierProvider.notifier);
    try {
      final saleId = await notifier.chargeAndPersist();
      await _playChargeSound();
      if (mounted) {
        await _showSaleSuccessOverlay(chargedAmount);
        context.go('/sales/receipt/$saleId');
        if (cart.customerId != null && expectedEarn > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Earned $expectedEarn points!')));
        }
        setState(() {
          _redeemSelected = false;
          _redeemPoints = 0;
          _loyaltySavings = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isCharging = false);
      }
    }
  }

  Future<void> _loadLoyaltyBalance(int? customerId) async {
    if (customerId == null) {
      setState(() => _loyaltyBalance = 0);
      return;
    }
    final repo = ref.read(loyaltyRepositoryProvider);
    final balance = await repo.getBalance(customerId);
    if (mounted) {
      setState(() => _loyaltyBalance = balance);
    }
  }

  void _showAddToCartFly(Offset sourceGlobal) {
    final overlay = Overlay.of(context);
    final cartContext = _cartBadgeKey.currentContext;
    if (cartContext == null) return;

    final cartBox = cartContext.findRenderObject() as RenderBox?;
    if (cartBox == null) return;

    final target =
    cartBox.localToGlobal(cartBox.size.center(Offset.zero));
    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    final curved =
    CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        final t = curved.value;
        final x = sourceGlobal.dx + (target.dx - sourceGlobal.dx) * t;
        final yBase =
            sourceGlobal.dy + (target.dy - sourceGlobal.dy) * t;
        final arc = math.sin(t * math.pi) * 22;
        return Positioned(
          left: x - 16,
          top: yBase - arc - 16,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0), // FIX: use double literals
              child: Transform.scale(
                scale: 0.9 + (0.2 * (1 - t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: pkGreen,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('+1',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        );
      },
    );

    controller
      ..addListener(entry.markNeedsBuild)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          entry.remove();
          controller.dispose();
        }
      });

    overlay.insert(entry);
    controller.forward();
  }

  Future<void> _showSaleSuccessOverlay(double amount) async {
    if (!mounted) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'sale-success',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _SaleSuccessOverlay(amount: amount),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      final rootNav = Navigator.of(context, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
      }
    }
  }
}

class _ProductsPanel extends ConsumerWidget {
  const _ProductsPanel({
    required this.productsRepo,
    required this.searchController,
    required this.onSearchChanged,
    required this.onProductAdded,
    required this.search,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  final ProductsRepository productsRepo;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Offset> onProductAdded;
  final String search;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesRepo = ref.watch(categoriesRepositoryProvider);
    final money =
    NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Barcode ya naam likhein...',
                prefixIcon: const Icon(Icons.search),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: pkGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: pkGreen, width: 1.5),
                ),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Category>>(
              stream: categoriesRepo.watchAll(),
              builder: (context, snapshot) {
                final categories =
                    snapshot.data ?? const <Category>[];
                return SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: selectedCategoryId == null,
                        onTap: () => onSelectCategory(null),
                      ),
                      ...categories.map(
                            (c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _CategoryChip(
                            label: c.name,
                            selected: selectedCategoryId == c.id,
                            onTap: () => onSelectCategory(c.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: productsRepo.watchPaged(
                    limit: 120,
                    categoryId: selectedCategoryId,
                    search: search),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _ProductGridSkeleton();
                  }
                  final products =
                      snapshot.data ?? const <Product>[];
                  if (products.isEmpty) {
                    return const Center(
                        child: Text('No products found'));
                  }
                  return GridView.builder(
                    itemCount: products.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.25,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductCard(
                        product: product,
                        formattedPrice:
                        money.format(product.salePrice),
                        onAdded: onProductAdded,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label,
        required this.selected,
        required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? pkGold : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pkGreen),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1F2B1F) : pkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  const _ProductCard(
      {required this.product,
        required this.formattedPrice,
        required this.onAdded});

  final Product product;
  final String formattedPrice;
  final ValueChanged<Offset> onAdded;

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1, end: 0.95).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      widget.onAdded(box.localToGlobal(box.size.center(Offset.zero)));
    }
    await _controller.forward();
    await _controller.reverse();
    ref.read(cartNotifierProvider.notifier).addItem(widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final isLowStock = widget.product.reorderLevel > 0 &&
        widget.product.stockQuantity <= widget.product.reorderLevel;

    return ScaleTransition(
      scale: _scale,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _add,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  widget.formattedPrice,
                  style: const TextStyle(
                      color: pkGreen, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    // FIX: withOpacity → withValues(alpha:)
                    color: isLowStock
                        ? pkRed
                        : pkGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Stock ${widget.product.stockQuantity}',
                    style: TextStyle(
                        color: isLowStock ? Colors.white : pkGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
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

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel({
    required this.isCharging,
    required this.orderDiscountController,
    required this.amountTenderedController,
    required this.customersRepo,
    required this.selectedCustomerId,
    required this.onSelectCustomer,
    required this.onCharge,
    required this.cartBadgeKey,
    required this.loyaltyBalance,
    required this.redeemPoints,
    required this.loyaltySavings,
    required this.redeemSelected,
    required this.settings,
    required this.onToggleRedeem,
  });

  final bool isCharging;
  final TextEditingController orderDiscountController;
  final TextEditingController amountTenderedController;
  final CustomersRepository customersRepo;
  final int? selectedCustomerId;
  final ValueChanged<int?> onSelectCustomer;
  final VoidCallback onCharge;
  final GlobalKey cartBadgeKey;
  final int loyaltyBalance;
  final int redeemPoints;
  final double loyaltySavings;
  final bool redeemSelected;
  final ShopSettings? settings;
  final void Function(bool selected, int points, double savings)
  onToggleRedeem;

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeBounceController;
  late final Animation<double> _badgeScale;
  int? _lastItemCount;

  @override
  void initState() {
    super.initState();
    _badgeBounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 1.3), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 1), weight: 50),
    ]).animate(CurvedAnimation(
        parent: _badgeBounceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _badgeBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartNotifierProvider);
    final itemCount =
    cart.items.fold<int>(0, (sum, item) => sum + item.quantity);
    if (_lastItemCount != itemCount) {
      final previous = _lastItemCount;
      _lastItemCount = itemCount;
      if (previous != null && itemCount > previous) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _badgeBounceController
              ..reset()
              ..forward();
          }
        });
      }
    }

    final taxRate = widget.settings?.taxRate ?? 0;
    final taxableBase =
    (cart.subtotal - cart.discountAmount).clamp(0.0, double.maxFinite); // FIX: double literals → returns double
    final taxValue =
    taxRate > 0 ? taxableBase * (taxRate / 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: pkGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bill / بل',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
                  ScaleTransition(
                    scale: _badgeScale,
                    child: Badge(
                      key: widget.cartBadgeKey,
                      backgroundColor: pkGold,
                      textColor: pkGreen,
                      label: Text('$itemCount'),
                      child: const Icon(Icons.shopping_cart_outlined,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Customer>>(
              stream: widget.customersRepo.watchAll(),
              builder: (context, snapshot) {
                final customers =
                    snapshot.data ?? const <Customer>[];
                return DropdownButtonFormField<int?>(
                  initialValue: widget.selectedCustomerId,
                  decoration: const InputDecoration(
                      labelText: 'Customer (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Walk-in')),
                    ...customers.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: UrduAwareText(c.name))),
                  ],
                  onChanged: widget.onSelectCustomer,
                );
              },
            ),
            const SizedBox(height: 8),
            if (widget.selectedCustomerId != null &&
                widget.settings != null &&
                widget.loyaltyBalance > 0)
              _LoyaltyRedeemTile(
                balance: widget.loyaltyBalance,
                settings: widget.settings!,
                cartTotal: cart.total,
                redeemSelected: widget.redeemSelected,
                onToggle: (selected) {
                  final available = widget.loyaltyBalance;
                  final baseTotal =
                      cart.total + cart.loyaltyDiscount;
                  final maxPointsByTotal =
                  (baseTotal / widget.settings!.rupeePerPoint)
                      .floor();
                  final pointsToRedeem = selected
                      ? [available, maxPointsByTotal]
                      .where((v) => v > 0)
                      .fold<int>(available, (a, b) => a < b ? a : b)
                      : 0;
                  final meetsMin = pointsToRedeem >=
                      widget.settings!.minRedeemPoints;
                  final finalPoints =
                  selected && meetsMin ? pointsToRedeem : 0;
                  final savings =
                      finalPoints * widget.settings!.rupeePerPoint;
                  widget.onToggleRedeem(
                      selected && meetsMin, finalPoints, savings);
                  if (selected && !meetsMin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Minimum ${widget.settings!.minRedeemPoints} points to redeem')),
                    );
                  }
                },
                pointsRedeemed: widget.redeemPoints,
                savings: widget.loyaltySavings,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: cart.items.isEmpty
                  ? const _CartEmptyState()
                  : ListView.separated(
                itemCount: cart.items.length,
                separatorBuilder: (_, _) =>
                const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _CartLine(item: cart.items[index]),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.orderDiscountController,
              decoration: const InputDecoration(
                  labelText: 'Order discount (%)'),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              onChanged: (value) => ref
                  .read(cartNotifierProvider.notifier)
                  .setOrderDiscount(double.tryParse(value) ?? 0),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PaymentChip(
                    method: PaymentMethod.cash,
                    active:
                    cart.paymentMethod == PaymentMethod.cash,
                    onTap: () => ref
                        .read(cartNotifierProvider.notifier)
                        .setPaymentMethod(PaymentMethod.cash)),
                _PaymentChip(
                    method: PaymentMethod.easypaisa,
                    active: cart.paymentMethod ==
                        PaymentMethod.easypaisa,
                    onTap: () => ref
                        .read(cartNotifierProvider.notifier)
                        .setPaymentMethod(PaymentMethod.easypaisa)),
                _PaymentChip(
                    method: PaymentMethod.jazzcash,
                    active: cart.paymentMethod ==
                        PaymentMethod.jazzcash,
                    onTap: () => ref
                        .read(cartNotifierProvider.notifier)
                        .setPaymentMethod(PaymentMethod.jazzcash)),
                _PaymentChip(
                    method: PaymentMethod.bank,
                    active:
                    cart.paymentMethod == PaymentMethod.bank,
                    onTap: () => ref
                        .read(cartNotifierProvider.notifier)
                        .setPaymentMethod(PaymentMethod.bank)),
                _PaymentChip(
                    method: PaymentMethod.credit,
                    active: cart.paymentMethod ==
                        PaymentMethod.credit,
                    onTap: () => ref
                        .read(cartNotifierProvider.notifier)
                        .setPaymentMethod(PaymentMethod.credit)),
              ],
            ),
            const SizedBox(height: 8),
            if (cart.paymentMethod == PaymentMethod.cash) ...[
              TextField(
                controller: widget.amountTenderedController,
                decoration: const InputDecoration(
                    labelText: 'Amount tendered'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                onChanged: (value) => ref
                    .read(cartNotifierProvider.notifier)
                    .setAmountTendered(
                    double.tryParse(value) ?? 0),
              ),
              const SizedBox(height: 6),
              Text(
                'Change: PKR ${cart.change.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: pkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 6),
            _totalRow('Subtotal', cart.subtotal),
            _totalRow('Discount', cart.discountAmount),
            if (taxRate > 0)
              _totalRow(
                  'Tax (${taxRate.toStringAsFixed(1)}%)', taxValue.toDouble()),
            if (cart.loyaltyDiscount > 0)
              _totalRow('Loyalty', cart.loyaltyDiscount),
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: pkGreen)),
                Text('PKR ${cart.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: pkGreen)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: pkGreen,
                    foregroundColor: Colors.white),
                onPressed:
                widget.isCharging ? null : widget.onCharge,
                child: widget.isCharging
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Text('CHARGE — وصول کریں',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('PKR ${value.toStringAsFixed(0)}'),
        ],
      ),
    );
  }
}

class _CartLine extends ConsumerStatefulWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  ConsumerState<_CartLine> createState() => _CartLineState();
}

class _CartLineState extends ConsumerState<_CartLine> {
  bool _showDiscount = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: UrduAwareText(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('PKR ${item.lineTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _QtyStepper(
                quantity: item.quantity,
                onMinus: () => ref
                    .read(cartNotifierProvider.notifier)
                    .updateQty(item.productId, item.quantity - 1),
                onPlus: () => ref
                    .read(cartNotifierProvider.notifier)
                    .updateQty(item.productId, item.quantity + 1),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  // FIX: withOpacity → withValues(alpha:)
                  backgroundColor: pkGoldSoft,
                  foregroundColor: const Color(0xFF5E4A00),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () =>
                    setState(() => _showDiscount = !_showDiscount),
                icon: const Icon(Icons.percent, size: 14),
                label: const Text('% disc'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref
                    .read(cartNotifierProvider.notifier)
                    .removeItem(item.productId),
              ),
            ],
          ),
          if (_showDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue:
                  item.lineDiscountPercent.toStringAsFixed(0),
                  decoration: const InputDecoration(
                      isDense: true, hintText: '%'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (value) => ref
                      .read(cartNotifierProvider.notifier)
                      .setLineDiscount(item.productId,
                      double.tryParse(value) ?? 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper(
      {required this.quantity,
        required this.onMinus,
        required this.onPlus});

  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // FIX: withOpacity → withValues(alpha:)
          border: Border.all(
              color: pkGreen.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.remove,
                  color: pkGreen, size: 18),
              onPressed: onMinus),
          Text('$quantity',
              style: const TextStyle(
                  color: pkGreen, fontWeight: FontWeight.w700)),
          IconButton(
              icon:
              const Icon(Icons.add, color: pkGreen, size: 18),
              onPressed: onPlus),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip(
      {required this.method,
        required this.active,
        required this.onTap});

  final PaymentMethod method;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cfg = _paymentConfig(method);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // FIX: withOpacity → withValues(alpha:)
          color: active
              ? cfg.color
              : cfg.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cfg.color),
        ),
        child: Text(
          cfg.label,
          style: TextStyle(
              color: active ? Colors.white : cfg.color,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  _PaymentConfig _paymentConfig(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return const _PaymentConfig('Cash', pkGreen);
      case PaymentMethod.easypaisa:
        return const _PaymentConfig(
            'EasyPaisa', Color(0xFF00897B));
      case PaymentMethod.jazzcash:
        return const _PaymentConfig(
            'JazzCash', Color(0xFFC62828));
      case PaymentMethod.bank:
        return const _PaymentConfig('Bank', Color(0xFF1565C0));
      case PaymentMethod.credit:
        return const _PaymentConfig('Udhar', pkGold);
    }
  }
}

class _PaymentConfig {
  const _PaymentConfig(this.label, this.color);

  final String label;
  final Color color;
}

class _CartEmptyState extends StatelessWidget {
  const _CartEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              // FIX: withOpacity → withValues(alpha:)
                color: Color(0x1A01411C),
                shape: BoxShape.circle),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 30,
                    decoration: BoxDecoration(
                      border:
                      Border.all(color: pkGreen, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    child: Container(
                      width: 18,
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: pkGreen, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Cart خالی ہے',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: pkGreen)),
        ],
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 12,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 13,
                      width: double.infinity,
                      color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                      height: 13,
                      width: 110,
                      color: Colors.white),
                  const Spacer(),
                  Container(
                      height: 12, width: 80, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                      height: 20, width: 70, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaleSuccessOverlay extends StatefulWidget {
  const _SaleSuccessOverlay({required this.amount});

  final double amount;

  @override
  State<_SaleSuccessOverlay> createState() =>
      _SaleSuccessOverlayState();
}

class _SaleSuccessOverlayState extends State<_SaleSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 650))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pkGreen,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CheckmarkPainter(
                        progress: _controller.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text('Sale Complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('PKR ${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(
        size.center(Offset.zero), size.width * 0.44, circlePaint);

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = Offset(size.width * 0.28, size.height * 0.54);
    final p2 = Offset(size.width * 0.45, size.height * 0.7);
    final p3 = Offset(size.width * 0.75, size.height * 0.38);
    final path = Path()..moveTo(p1.dx, p1.dy);

    // FIX: use double literals 0.0 and 1.0 so clamp returns double
    final firstPart = (progress * 2).clamp(0.0, 1.0);
    if (firstPart > 0) {
      final mid = Offset.lerp(p1, p2, firstPart)!;
      path.lineTo(mid.dx, mid.dy);
    }

    final secondPart = ((progress - 0.5) * 2).clamp(0.0, 1.0);
    if (secondPart > 0) {
      final end = Offset.lerp(p2, p3, secondPart)!;
      if (firstPart < 1) {
        path.lineTo(p2.dx, p2.dy);
      }
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LoyaltyRedeemTile extends StatelessWidget {
  const _LoyaltyRedeemTile({
    required this.balance,
    required this.settings,
    required this.cartTotal,
    required this.redeemSelected,
    required this.onToggle,
    required this.pointsRedeemed,
    required this.savings,
  });

  final int balance;
  final ShopSettings settings;
  final double cartTotal;
  final bool redeemSelected;
  final ValueChanged<bool> onToggle;
  final int pointsRedeemed;
  final double savings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('Loyalty balance: $balance pts'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Min redeem: ${settings.minRedeemPoints} pts · Value per point: ${settings.rupeePerPoint.toStringAsFixed(2)}'),
          if (redeemSelected && pointsRedeemed > 0)
            Text(
                'Redeeming $pointsRedeemed pts → saves ${savings.toStringAsFixed(2)}'),
        ],
      ),
      trailing: Switch(
        value: redeemSelected,
        onChanged: balance >= settings.minRedeemPoints && cartTotal > 0
            ? onToggle
            : null,
      ),
    );
  }
}