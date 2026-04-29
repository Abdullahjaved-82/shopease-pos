import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos_system/core/database/app_database.dart';
import 'package:pos_system/core/providers/repositories.dart';
import 'package:pos_system/core/repositories/categories_repository.dart';

part 'categories_notifier.g.dart';

const presetCategoryColors = <String>[
  '#F44336', // red
  '#E91E63', // pink
  '#9C27B0', // purple
  '#3F51B5', // indigo
  '#2196F3', // blue
  '#03A9F4', // light blue
  '#00BCD4', // cyan
  '#009688', // teal
  '#4CAF50', // green
  '#FF9800', // orange
  '#795548', // brown
  '#607D8B', // blue grey
];

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  StreamSubscription<List<CategoryWithCount>>? _subscription;
  late final CategoriesRepository _repository;

  @override
  FutureOr<List<CategoryWithCount>> build() async {
    _repository = ref.watch(categoriesRepositoryProvider);
    _subscription ??= _repository.watchWithCounts().listen((data) {
      state = AsyncData(data);
    });

    ref.onDispose(() async {
      await _subscription?.cancel();
    });

    return _repository.fetchWithCounts();
  }

  Future<void> addCategory({required String name, required String colorHex}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repository.insert(
      CategoriesCompanion(
        name: Value(trimmed),
        colorHex: Value(colorHex),
      ),
    );
  }

  Future<void> renameCategory({required int id, required String name, required String colorHex}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repository.updateNameAndColor(id: id, name: trimmed, colorHex: colorHex);
  }

  Future<int> productCount(int id) => _repository.countProductsForCategory(id);

  Future<void> deleteCategory(int id) async {
    await _repository.deleteById(id);
  }
}

