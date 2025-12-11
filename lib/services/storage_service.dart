import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu.dart';
import '../models/recipe.dart';

enum MealCategory { breakfast, lunch, dinner }

class StorageService {
  static const _menuFiles = ['healthy', 'quick', 'vegetarian'];
  static const _recipeFiles = [
    'ButterChicken',
    'PastaParmesan',
    'MarinatedPorkWithPotatos',
    'BarbequeChickenWithTortellini',
  ];

  // Recipes organized by meal category
  static const Map<MealCategory, List<String>> _categoryRecipes = {
    MealCategory.breakfast: [
      'breakfast/HearthyKesam',
      'breakfast/ProteinShake',
    ],
    MealCategory.lunch: [
      'lunch/ProteinPancakes',
    ],
    MealCategory.dinner: [
      'recipes/BarbequeChickenWithTortellini',
      'recipes/ButterChicken',
      'recipes/Goulash',
      'recipes/Lasagna',
      'recipes/MarinatedPorkWithPotatos',
      'recipes/MeatballSoup',
      'recipes/PastaParmesan',
      'recipes/RedBeetSoup',
    ],
  };

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('StorageService not initialized');
    return _prefs!;
  }

  // Menu loading
  static List<String> get menuIds => _menuFiles;
  static List<String> get recipeIds => _recipeFiles;

  Future<Map<String, Menu>> loadMenus() async {
    final menus = <String, Menu>{};
    for (final id in _menuFiles) {
      final jsonString = await rootBundle.loadString('assets/menus/$id.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      menus[id] = Menu.fromJson(id, data);
    }
    return menus;
  }

  Future<Map<String, Recipe>> loadRecipes() async {
    final recipes = <String, Recipe>{};
    for (final id in _recipeFiles) {
      final jsonString = await rootBundle.loadString('assets/recipes/$id.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      recipes[id] = Recipe.fromJson(id, data);
    }
    return recipes;
  }

  // Load recipes by meal category
  Future<Map<String, Recipe>> loadRecipesByCategory(MealCategory category) async {
    final recipes = <String, Recipe>{};
    final paths = _categoryRecipes[category] ?? [];
    for (final path in paths) {
      try {
        final id = path.split('/').last;
        final jsonString = await rootBundle.loadString('assets/$path.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        recipes[id] = Recipe.fromJson(id, data);
      } catch (e) {
        // Skip recipes that fail to load
        debugPrint('Failed to load recipe at $path: $e');
      }
    }
    return recipes;
  }

  // Load all recipes from all categories
  Future<Map<MealCategory, Map<String, Recipe>>> loadAllCategoryRecipes() async {
    final allRecipes = <MealCategory, Map<String, Recipe>>{};
    for (final category in MealCategory.values) {
      try {
        allRecipes[category] = await loadRecipesByCategory(category);
      } catch (e) {
        allRecipes[category] = {};
        debugPrint('Failed to load category $category: $e');
      }
    }
    return allRecipes;
  }

  // Default dinner replacements (dayIdx-mealIdx -> recipeId)
  // Days: 0=Monday, 1=Tuesday, 2=Wednesday, 3=Thursday, 4=Friday, 5=Saturday, 6=Sunday
  // Meals: 0=Breakfast, 1=Lunch, 2=Dinner
  static const Map<String, String> _defaultMealReplacements = {
    // Breakfast (ProteinShake weekdays, Kesam weekends)
    '0-0': 'ProteinShake',       // Monday breakfast
    '1-0': 'ProteinShake',       // Tuesday breakfast
    '2-0': 'ProteinShake',       // Wednesday breakfast
    '3-0': 'ProteinShake',       // Thursday breakfast
    '4-0': 'ProteinShake',       // Friday breakfast
    '5-0': 'HearthyKesam',       // Saturday breakfast
    '6-0': 'HearthyKesam',       // Sunday breakfast
    // Lunch (Pancakes every day)
    '0-1': 'ProteinPancakes',    // Monday lunch
    '1-1': 'ProteinPancakes',    // Tuesday lunch
    '2-1': 'ProteinPancakes',    // Wednesday lunch
    '3-1': 'ProteinPancakes',    // Thursday lunch
    '4-1': 'ProteinPancakes',    // Friday lunch
    '5-1': 'ProteinPancakes',    // Saturday lunch
    '6-1': 'ProteinPancakes',    // Sunday lunch
    // Dinner
    '0-2': 'Goulash',                        // Monday dinner
    '1-2': 'ButterChicken',                  // Tuesday dinner
    '2-2': 'ButterChicken',                  // Wednesday dinner
    '3-2': 'BarbequeChickenWithTortellini',  // Thursday dinner
    '4-2': 'Lasagna',                        // Friday dinner
    '5-2': 'MarinatedPorkWithPotatos',       // Saturday dinner
    '6-2': 'PastaParmesan',                  // Sunday dinner
  };

  // Meal replacements (dayIdx-mealIdx -> recipeId)
  Map<String, String> loadMealReplacements() {
    // Always use defaults for now (remove this line later to persist user changes)
    return Map.from(_defaultMealReplacements);
  }

  Future<void> saveMealReplacements(Map<String, String> replacements) async {
    await prefs.setString('mealReplacements', json.encode(replacements));
  }

  // Selected menus per day
  Map<int, String> loadSelectedMenus() {
    final selections = <int, String>{};
    for (int i = 0; i < 7; i++) {
      selections[i] = prefs.getString('menu_$i') ?? _menuFiles.first;
    }
    return selections;
  }

  Future<void> saveSelectedMenu(int dayIdx, String menuId) async {
    await prefs.setString('menu_$dayIdx', menuId);
  }

  // Custom times
  Map<String, String> loadCustomTimes() {
    final timesJson = prefs.getString('customTimes');
    if (timesJson == null) return {};
    final decoded = json.decode(timesJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveCustomTimes(Map<String, String> times) async {
    await prefs.setString('customTimes', json.encode(times));
  }

  // Settings
  bool get notificationsEnabled => prefs.getBool('notif') ?? true;
  Future<void> setNotificationsEnabled(bool value) => prefs.setBool('notif', value);

  bool get vibrationEnabled => prefs.getBool('vib') ?? true;
  Future<void> setVibrationEnabled(bool value) => prefs.setBool('vib', value);

  // Completed meals
  Set<String> loadCompleted() {
    return prefs.getStringList('done')?.toSet() ?? {};
  }

  Future<void> saveCompleted(Set<String> completed) async {
    await prefs.setStringList('done', completed.toList());
  }

  // Checked ingredients
  Set<String> loadCheckedIngredients() {
    return prefs.getStringList('checkedIngredients')?.toSet() ?? {};
  }

  Future<void> saveCheckedIngredients(Set<String> checked) async {
    await prefs.setStringList('checkedIngredients', checked.toList());
  }
}
