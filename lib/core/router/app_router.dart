import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/application/auth_state.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/features/auth/presentation/login_page.dart';
import 'package:pos_system/features/dashboard/presentation/dashboard_page.dart';
import 'package:pos_system/features/customers/presentation/customer_list_page.dart';
import 'package:pos_system/features/customers/presentation/customer_form_page.dart';
import 'package:pos_system/features/customers/presentation/customer_detail_page.dart';
import 'package:pos_system/features/inventory/presentation/inventory_page.dart';
import 'package:pos_system/features/invoices/presentation/invoice_form_page.dart';
import 'package:pos_system/features/invoices/presentation/invoice_list_page.dart';
import 'package:pos_system/features/invoices/presentation/invoice_detail_page.dart';
import 'package:pos_system/features/invoices/presentation/recurring_invoices_list_page.dart';
import 'package:pos_system/features/invoices/domain/document_models.dart';
import 'package:pos_system/features/products/presentation/product_detail_page.dart';
import 'package:pos_system/features/products/presentation/product_form_page.dart';
import 'package:pos_system/features/products/presentation/product_list_page.dart';
import 'package:pos_system/features/products/presentation/category_management_page.dart';
import 'package:pos_system/features/reports/presentation/reports_page.dart';
import 'package:pos_system/features/reports/presentation/shift_summary_page.dart';
import 'package:pos_system/features/sales/presentation/sales_page.dart';
import 'package:pos_system/features/sales/presentation/receipt_page.dart';
import 'package:pos_system/features/settings/presentation/shop_settings_page.dart';
import 'package:pos_system/features/settings/presentation/backup_page.dart';
import 'package:pos_system/features/settings/presentation/import_products_page.dart';
import 'package:pos_system/features/shared/presentation/home_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) => resolveRedirect(authState, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(state: state, child: const LoginPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => _fadePage(state: state, child: const DashboardPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                pageBuilder: (context, state) => _fadePage(state: state, child: const SalesPage()),
                routes: [
                  GoRoute(
                    path: 'receipt/:id',
                    pageBuilder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return _slidePage(state: state, child: ReceiptPage(saleId: id));
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                pageBuilder: (context, state) => _fadePage(state: state, child: const ProductListPage()),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoryManagementPage(),
                  ),
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ProductFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return _slidePage(state: state, child: ProductDetailPage(id: id));
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final id = int.parse(state.pathParameters['id']!);
                          return ProductFormPage(productId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                pageBuilder: (context, state) => _fadePage(state: state, child: const InventoryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                pageBuilder: (context, state) => _fadePage(state: state, child: const InvoiceListPage()),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const InvoiceFormPage(),
                  ),
                  GoRoute(
                    path: 'new/quotation',
                    builder: (context, state) => const InvoiceFormPage(docType: DocumentType.quotation),
                  ),
                  GoRoute(
                    path: 'new/proforma',
                    builder: (context, state) => const InvoiceFormPage(docType: DocumentType.proforma),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) => const RecurringInvoicesListPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => InvoiceDetailPage(invoiceId: int.parse(state.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (context, state) => InvoiceFormPage(invoiceId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                pageBuilder: (context, state) => _fadePage(state: state, child: const ReportsPage()),
                routes: [
                  GoRoute(
                    path: 'shifts',
                    builder: (context, state) => const ShiftSummaryPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                pageBuilder: (context, state) => _fadePage(state: state, child: const CustomerListPage()),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const CustomerFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => _slidePage(
                      state: state,
                      child: CustomerDetailPage(id: int.parse(state.pathParameters['id']!)),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => CustomerFormPage(customerId: int.parse(state.pathParameters['id']!)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => _fadePage(state: state, child: const ShopSettingsPage()),
                routes: [
                  GoRoute(
                    path: 'backup',
                    builder: (context, state) => const BackupPage(),
                  ),
                  GoRoute(
                    path: 'import-products',
                    builder: (context, state) => const ImportProductsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String? resolveRedirect(AuthState authState, String matchedLocation) {
  final loggingIn = matchedLocation == '/login';

  if (!authState.isAuthenticated) {
    return loggingIn ? null : '/login';
  }

  if (loggingIn) {
    return authState.role == UserRole.admin ? '/dashboard' : '/sales';
  }

  if (authState.role == UserRole.cashier) {
    const allowedPrefixes = ['/sales', '/customers', '/invoices'];
    final allowed = allowedPrefixes.any((prefix) => matchedLocation.startsWith(prefix));
    if (!allowed) {
      return '/sales';
    }
  }

  if (authState.role != UserRole.admin && matchedLocation.startsWith('/dashboard')) {
    return '/sales';
  }

  if (authState.role != UserRole.admin && matchedLocation.startsWith('/settings')) {
    return '/sales';
  }

  return null;
}

CustomTransitionPage<void> _fadePage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _slidePage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

