import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu.dart';
import '../models/recipe.dart';

class StorageService {
  static const _menuFiles = ['healthy', 'quick', 'vegetarian'];
  static const _recipeFiles = [
    'ButterChicken',
    'PastaParmesan',
    'MarinatedPorkWithPotatos',
    'BarbequeChickenWithTortellini',
  ];

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

  // Meal replacements (dayIdx-mealIdx -> recipeId)
  Map<String, String> loadMealReplacements() {
    final replacementsJson = prefs.getString('mealReplacements');
    if (replacementsJson == null) return {};
    final decoded = json.decode(replacementsJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
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
