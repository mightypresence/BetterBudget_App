import 'package:budget_app/data/repository.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/theme_preset.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/services/shared_ledger_service.dart';
import 'package:budget_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryRepository repository;
  late BudgetController budgetController;

  setUp(() {
    repository = MemoryRepository();
    budgetController = BudgetController(
      BudgetService(repository),
      SharedLedgerService(repository),
    );
  });

  group('主題系統', () {
    test('預設主題為經典森林（免費）', () {
      expect(budgetController.themePreset.id, 'forest');
      expect(
        budgetController.isThemeUnlocked(budgetController.themePreset),
        isTrue,
      );
    });

    test('免費主題不需解鎖即可使用', () {
      expect(
        budgetController.isThemeUnlocked(kThemePresets[1]),
        isTrue,
      ); // ocean
    });

    test('付費主題預設鎖定', () {
      expect(
        budgetController.isThemeUnlocked(kThemePresets[2]),
        isFalse,
      ); // neon
    });

    test('切換主題持久化', () async {
      await budgetController.setTheme('ocean');
      expect(budgetController.themePreset.id, 'ocean');
      // 新 controller（模擬重開 App）讀取相同 repo
      final restoredBudgetController = BudgetController(
        BudgetService(repository),
        SharedLedgerService(repository),
      );
      expect(restoredBudgetController.themePreset.id, 'ocean');
    });

    test('解鎖付費主題並自動套用', () async {
      await budgetController.unlockTheme('neon');
      expect(budgetController.isThemeUnlocked(kThemePresets[2]), isTrue);
      expect(budgetController.themePreset.id, 'neon');
    });

    test('解鎖狀態持久化', () async {
      await budgetController.unlockTheme('pastel');
      final restoredBudgetController = BudgetController(
        BudgetService(repository),
        SharedLedgerService(repository),
      );
      expect(
        restoredBudgetController.isThemeUnlocked(kThemePresets[3]),
        isTrue,
      );
    });

    test('主題產生亮暗色 ThemeData（seed 不同主色不同）', () {
      final forest = buildLightTheme(themePresetById('forest'));
      final ocean = buildLightTheme(themePresetById('ocean'));
      expect(forest.colorScheme.primary, isNot(ocean.colorScheme.primary));
      final dark = buildDarkTheme(themePresetById('neon'));
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('未知主題 id 退回預設', () {
      expect(themePresetById('nonexistent').id, 'forest');
    });
  });

  group('Pro 會員功能分層', () {
    test('預設非 Pro，可新增 3 個類別', () async {
      expect(budgetController.isPro, isFalse);
      for (var itemIndex = 0; itemIndex < 3; itemIndex++) {
        await budgetController.upsertCategory(
          BudgetCategory(id: 'c$itemIndex', name: '類別$itemIndex'),
        );
      }
      expect(budgetController.canAddCategory, isFalse); // 第 4 個被擋
    });

    test('升級 Pro 後無限類別', () async {
      await budgetController.upgradeToPro();
      expect(budgetController.isPro, isTrue);
      for (var itemIndex = 0; itemIndex < 10; itemIndex++) {
        await budgetController.upsertCategory(
          BudgetCategory(id: 'c$itemIndex', name: '類別$itemIndex'),
        );
      }
      expect(budgetController.canAddCategory, isTrue);
    });

    test('Pro 狀態持久化', () async {
      await budgetController.upgradeToPro();
      final restoredBudgetController = BudgetController(
        BudgetService(repository),
        SharedLedgerService(repository),
      );
      expect(restoredBudgetController.isPro, isTrue);
    });
  });

  group('類別拖拽排序', () {
    test('重排類別並持久化', () async {
      for (var itemIndex = 0; itemIndex < 4; itemIndex++) {
        await budgetController.upsertCategory(
          BudgetCategory(id: 'c$itemIndex', name: '類別$itemIndex'),
        );
      }
      // 把 c3 移到最前面
      final categories = List<BudgetCategory>.from(budgetController.categories);
      final moved = categories.removeAt(3);
      categories.insert(0, moved);
      await budgetController.reorderCategories(categories);

      expect(budgetController.categories.first.id, 'c3');
      // 重開後順序保留
      final restoredBudgetController = BudgetController(
        BudgetService(repository),
        SharedLedgerService(repository),
      );
      expect(
        restoredBudgetController.categories
            .map((currentItem) => currentItem.id)
            .toList(),
        ['c3', 'c0', 'c1', 'c2'],
      );
    });
  });
}
