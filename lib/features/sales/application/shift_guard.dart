import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/features/auth/application/auth_controller.dart';
import 'package:pos_system/features/auth/application/auth_state.dart';
import 'package:pos_system/features/auth/domain/user_role.dart';
import 'package:pos_system/core/repositories/shifts_repository.dart';

final currentShiftProvider = StreamProvider<Shift?>((ref) {
  final auth = ref.watch(authControllerProvider);
  final repo = ref.watch(shiftsRepositoryProvider);
  final userId = auth.userId;
  if (userId == null) {
    return const Stream.empty();
  }
  return repo.watchCurrentShift(userId: userId);
});

class ShiftGuard {
  ShiftGuard(this.ref);

  final WidgetRef ref;

  ShiftsRepository get _repo => ref.read(shiftsRepositoryProvider);
  AuthState get _auth => ref.read(authControllerProvider);

  Future<Shift?> ensureOpenShift(BuildContext context) async {
    final shift = ref.read(currentShiftProvider).valueOrNull;
    if (shift != null) return shift;
    return _promptOpenShift(context);
  }

  Future<Shift?> _promptOpenShift(BuildContext context) async {
    final userId = _auth.userId;
    if (userId == null) return null;
    final controller = TextEditingController(text: '0');
    final result = await showDialog<double?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Shift'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Opening cash'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(ctx).pop(value);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (result == null) return null;
    return _repo.openShift(userId: userId, openingCash: result);
  }

  Future<CashMovement?> addMovement(BuildContext context, {required String type}) async {
    final shift = ref.read(currentShiftProvider).valueOrNull;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open a shift first')));
      return null;
    }
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'in' ? 'Cash In' : 'Cash Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return null;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final reason = reasonCtrl.text.trim().isEmpty ? (type == 'in' ? 'Cash in' : 'Cash out') : reasonCtrl.text.trim();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than zero')));
      return null;
    }
    return _repo.addCashMovement(shiftId: shift.id, type: type, amount: amount, reason: reason);
  }

  Future<Shift?> closeShift(BuildContext context) async {
    final shift = ref.read(currentShiftProvider).valueOrNull;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No open shift')));
      return null;
    }
    final summary = await _repo.getCashSummary(shiftId: shift.id);
    final closingCtrl = TextEditingController(text: summary.expectedCash.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expected cash: ${summary.expectedCash.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            TextField(
              controller: closingCtrl,
              decoration: const InputDecoration(labelText: 'Actual cash in drawer'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Close shift')),
        ],
      ),
    );
    if (confirmed != true) return null;
    final closing = double.tryParse(closingCtrl.text.trim()) ?? summary.expectedCash;
    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
    return _repo.closeShift(shiftId: shift.id, closingCash: closing, note: note);
  }

  bool canOverrideWithoutShift() {
    return _auth.role == UserRole.admin;
  }
}

extension ShiftGuardX on WidgetRef {
  ShiftGuard get shiftGuard => ShiftGuard(this);
}

