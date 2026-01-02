import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../config/ciders.dart';
import '../models/menu.dart';
import '../models/recipe.dart';
import '../models/snack.dart';

enum MealCategory { breakfast, lunch, dinner }

class StorageService {
  // Date string format helper
  static String dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get weekday index (0=Monday, 6=Sunday) from DateTime
  static int getWeekdayIdx(DateTime date) {
    return date.weekday - 1;
  }
  static const _menuFiles = ['healthy', 'quick', 'vegetarian'];
  static const _recipeFiles = [
    'ButterChicken',
    'PastaParmesan',
    'MarinatedPorkWithPotatos',
    'BarbequeChickenWithTortellini',
    'ChiliConCarne',
  ];

  static const _drinkFiles = [
    'Mojito',
    'GinAndTonic',
    'MaiTai',
    'WhiskeySour',
    'AmarettoSour',
    'GrevensCiderSugarFree',
    'BulmersRedBerryLime',
    'Hurricane',
  ];

  static const _snackFiles = [
    'Egg',
    'Apple',
    'Banana',
    'Candy',
    'SweetBrunette',
    'Pringles',
    'DoubleChocolateFlarn',
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
      'dinner/Taco/TacoChicken',
      'dinner/Taco/TacoBeef',
      'recipes/MarinatedPorkWithPotatos',
      'recipes/MeatballSoup',
      'recipes/PastaParmesan',
      'recipes/RedBeetSoup',
      'recipes/ChiliConCarne',
    ],
  };

  SharedPreferences? _prefs;
  static const String _backupFileName = 'dayplanner_backup.json';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Try to restore from backup if prefs appear empty (fresh install)
    await _restoreFromBackupIfNeeded();
  }

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('StorageService not initialized');
    return _prefs!;
  }

  // Get the backup file path - uses external storage on Android (survives reinstall)
  Future<File> _getBackupFile() async {
    Directory? dir;
    if (Platform.isAndroid) {
      // External storage survives app reinstall
      dir = await getExternalStorageDirectory();
    }
    // Fallback to documents directory
    dir ??= await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupFileName');
  }

  // Check if this looks like a fresh install (no user data in prefs)
  bool _isLikelyFreshInstall() {
    // Check if key user data exists
    final hasReplacements = prefs.getString('mealReplacements') != null;
    final hasMenus = prefs.getString('selectedMenus') != null;
    final hasCompleted = prefs.getStringList('done')?.isNotEmpty ?? false;
    final hasDrinks = prefs.getString('dailyDrinksV2') != null;
    final hasSnacks = prefs.getString('dailySnacks') != null;
    final hasLiquids = prefs.getString('dailyLiquids') != null;
    return !hasReplacements && !hasMenus && !hasCompleted && !hasDrinks && !hasSnacks && !hasLiquids;
  }

  // Restore data from backup file if prefs are empty
  Future<void> _restoreFromBackupIfNeeded() async {
    if (!_isLikelyFreshInstall()) {
      debugPrint('StorageService: Data exists in prefs, skipping restore');
      return;
    }

    try {
      final file = await _getBackupFile();
      if (!await file.exists()) {
        debugPrint('StorageService: No backup file found');
        return;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      debugPrint('StorageService: Restoring from backup file...');

      // Restore all data
      if (data['mealReplacements'] != null) {
        await prefs.setString('mealReplacements', json.encode(data['mealReplacements']));
      }
      if (data['selectedMenus'] != null) {
        await prefs.setString('selectedMenus', json.encode(data['selectedMenus']));
      }
      if (data['customTimes'] != null) {
        await prefs.setString('customTimes', json.encode(data['customTimes']));
      }
      if (data['mealPortions'] != null) {
        await prefs.setString('mealPortions', json.encode(data['mealPortions']));
      }
      if (data['done'] != null) {
        await prefs.setStringList('done', List<String>.from(data['done']));
      }
      if (data['checkedIngredients'] != null) {
        await prefs.setStringList('checkedIngredients', List<String>.from(data['checkedIngredients']));
      }
      if (data['dailyDrinksV2'] != null) {
        await prefs.setString('dailyDrinksV2', json.encode(data['dailyDrinksV2']));
      }
      if (data['dailySnacks'] != null) {
        await prefs.setString('dailySnacks', json.encode(data['dailySnacks']));
      }
      if (data['dailyWater'] != null) {
        await prefs.setString('dailyWater', json.encode(data['dailyWater']));
      }
      if (data['dailyLiquids'] != null) {
        await prefs.setString('dailyLiquids', json.encode(data['dailyLiquids']));
      }
      if (data['notif'] != null) {
        await prefs.setBool('notif', data['notif'] as bool);
      }
      if (data['vib'] != null) {
        await prefs.setBool('vib', data['vib'] as bool);
      }

      debugPrint('StorageService: Backup restored successfully');
    } catch (e) {
      debugPrint('StorageService: Error restoring backup: $e');
    }
  }

  // Save all user data to backup file
  Future<void> backupToFile() async {
    try {
      final data = {
        'mealReplacements': prefs.getString('mealReplacements') != null
            ? json.decode(prefs.getString('mealReplacements')!)
            : null,
        'mealExtras': prefs.getString('mealExtras') != null
            ? json.decode(prefs.getString('mealExtras')!)
            : null,
        'selectedMenus': prefs.getString('selectedMenus') != null
            ? json.decode(prefs.getString('selectedMenus')!)
            : null,
        'customTimes': prefs.getString('customTimes') != null
            ? json.decode(prefs.getString('customTimes')!)
            : null,
        'mealPortions': prefs.getString('mealPortions') != null
            ? json.decode(prefs.getString('mealPortions')!)
            : null,
        'done': prefs.getStringList('done'),
        'checkedIngredients': prefs.getStringList('checkedIngredients'),
        'dailyDrinksV2': prefs.getString('dailyDrinksV2') != null
            ? json.decode(prefs.getString('dailyDrinksV2')!)
            : null,
        'dailySnacks': prefs.getString('dailySnacks') != null
            ? json.decode(prefs.getString('dailySnacks')!)
            : null,
        'dailyWater': prefs.getString('dailyWater') != null
            ? json.decode(prefs.getString('dailyWater')!)
            : null,
        'dailyLiquids': prefs.getString('dailyLiquids') != null
            ? json.decode(prefs.getString('dailyLiquids')!)
            : null,
        'notif': prefs.getBool('notif'),
        'vib': prefs.getBool('vib'),
        'backupDate': DateTime.now().toIso8601String(),
      };

      final file = await _getBackupFile();
      await file.writeAsString(json.encode(data));
      debugPrint('StorageService: Backup saved to ${file.path}');
    } catch (e) {
      debugPrint('StorageService: Error saving backup: $e');
    }
  }

  // Menu loading
  static List<String> get menuIds => _menuFiles;
  static List<String> get recipeIds => _recipeFiles;

  Future<Map<String, Menu>> loadMenus() async {
    final menus = <String, Menu>{};
    debugPrint('Loading menus: $_menuFiles');
    for (final id in _menuFiles) {
      try {
        final jsonString = await rootBundle.loadString('assets/menus/$id.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        menus[id] = Menu.fromJson(id, data);
        debugPrint('Successfully loaded menu: $id');
      } catch (e) {
        debugPrint('Failed to load menu $id: $e');
      }
    }
    debugPrint('Total menus loaded: ${menus.length}');
    return menus;
  }

  Future<Map<String, Recipe>> loadRecipes() async {
    final recipes = <String, Recipe>{};
    debugPrint('Loading recipes: $_recipeFiles');
    for (final id in _recipeFiles) {
      try {
        final jsonString = await rootBundle.loadString('assets/recipes/$id.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        recipes[id] = Recipe.fromJson(id, data);
        debugPrint('Successfully loaded recipe: $id');
      } catch (e) {
        debugPrint('Failed to load recipe $id: $e');
      }
    }
    debugPrint('Total recipes loaded: ${recipes.length}');
    return recipes;
  }

  Future<Map<String, Recipe>> loadDrinks() async {
    final drinks = <String, Recipe>{};
    debugPrint('Loading drinks: $_drinkFiles');
    for (final id in _drinkFiles) {
      try {
        final jsonString = await rootBundle.loadString('assets/drinks/$id.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        drinks[id] = Recipe.fromJson(id, data);
        debugPrint('Successfully loaded drink: $id');
      } catch (e) {
        debugPrint('Failed to load drink $id: $e');
      }
    }
    // Add ciders from config
    drinks.addAll(getCiderRecipes());
    // Add misc items (snus, etc.)
    drinks.addAll(getMiscRecipes());
    debugPrint('Total drinks loaded: ${drinks.length} (including ${allCiders.length} ciders)');
    return drinks;
  }

  Future<Map<String, Snack>> loadSnacks() async {
    final snacks = <String, Snack>{};
    debugPrint('Loading snacks: $_snackFiles');
    for (final id in _snackFiles) {
      try {
        final jsonString = await rootBundle.loadString('assets/snacks/$id.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        snacks[id] = Snack.fromJson(id, data);
        debugPrint('Successfully loaded snack: $id');
      } catch (e) {
        debugPrint('Failed to load snack $id: $e');
      }
    }
    debugPrint('Total snacks loaded: ${snacks.length}');
    return snacks;
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

  // No default meal replacements - days start blank
  // Meals are assigned per date: YYYY-MM-DD-mealIdx -> recipeId
  // Meals: 0=Breakfast, 1=Lunch, 2=Dinner

  // Meal replacements - date-based only (YYYY-MM-DD-mealIdx -> recipeId)
  Map<String, String> loadMealReplacements() {
    final replacementsJson = prefs.getString('mealReplacements');
    if (replacementsJson == null) {
      return {};
    }
    final decoded = json.decode(replacementsJson) as Map<String, dynamic>;
    final result = decoded.map((k, v) => MapEntry(k, v as String));

    // Clean up old weekday-based keys (0-0, 0-1, 0-2, 1-0, etc.)
    // Date-based keys look like: 2025-01-01-0
    final keysToRemove = result.keys.where((key) {
      // Weekday keys are short like "0-0", "1-2", etc.
      // Date keys are longer like "2025-01-01-0"
      return key.length < 6;
    }).toList();

    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        result.remove(key);
      }
      // Save the cleaned up data
      prefs.setString('mealReplacements', json.encode(result));
    }

    return result;
  }

  // Get meal replacement for a specific date (returns null if not assigned)
  String? getMealReplacementForDate(DateTime date, int mealIdx, Map<String, String> replacements) {
    final dateKey = '${dateToString(date)}-$mealIdx';
    return replacements[dateKey];
  }

  Future<void> saveMealReplacements(Map<String, String> replacements) async {
    await prefs.setString('mealReplacements', json.encode(replacements));
    await backupToFile();
  }

  // Save meal replacement for a specific date
  Future<void> saveMealReplacementForDate(DateTime date, int mealIdx, String? recipeId, Map<String, String> replacements) async {
    final dateKey = '${dateToString(date)}-$mealIdx';
    if (recipeId == null) {
      replacements.remove(dateKey);
    } else {
      replacements[dateKey] = recipeId;
    }
    await saveMealReplacements(replacements);
  }

  // ============== MEAL EXTRAS ==============
  // Additional ingredients added alongside the main recipe

  Map<String, List<String>> loadMealExtras() {
    final extrasJson = prefs.getString('mealExtras');
    if (extrasJson == null) {
      return {};
    }
    final decoded = json.decode(extrasJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as List).cast<String>()));
  }

  // Get meal extras for a specific date and meal slot
  List<String> getMealExtrasForDate(DateTime date, int mealIdx, Map<String, List<String>> extras) {
    final dateKey = '${dateToString(date)}-$mealIdx';
    return extras[dateKey] ?? [];
  }

  Future<void> saveMealExtras(Map<String, List<String>> extras) async {
    await prefs.setString('mealExtras', json.encode(extras));
    await backupToFile();
  }

  // Add a single extra item to a meal
  Future<void> addMealExtra(DateTime date, int mealIdx, String encodedItem, Map<String, List<String>> extras) async {
    final dateKey = '${dateToString(date)}-$mealIdx';
    extras[dateKey] ??= [];
    extras[dateKey]!.add(encodedItem);
    await saveMealExtras(extras);
  }

  // Remove a single extra item from a meal by index
  Future<void> removeMealExtra(DateTime date, int mealIdx, int index, Map<String, List<String>> extras) async {
    final dateKey = '${dateToString(date)}-$mealIdx';
    if (extras[dateKey] != null && index < extras[dateKey]!.length) {
      extras[dateKey]!.removeAt(index);
      if (extras[dateKey]!.isEmpty) {
        extras.remove(dateKey);
      }
      await saveMealExtras(extras);
    }
  }

  // Clear all extras for a meal slot
  Future<void> clearMealExtras(DateTime date, int mealIdx, Map<String, List<String>> extras) async {
    final dateKey = '${dateToString(date)}-$mealIdx';
    extras.remove(dateKey);
    await saveMealExtras(extras);
  }

  // Selected menus - now stored by date string
  Map<String, String> loadSelectedMenusMap() {
    final menusJson = prefs.getString('selectedMenus');
    if (menusJson == null) return {};
    final decoded = json.decode(menusJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  // Get menu for a specific date (checks date-specific first, then returns default)
  String getMenuForDate(DateTime date, Map<String, String> selectedMenus) {
    final dateKey = dateToString(date);
    if (selectedMenus.containsKey(dateKey)) {
      return selectedMenus[dateKey]!;
    }
    return _menuFiles.first;
  }

  Future<void> saveSelectedMenuForDate(DateTime date, String menuId, Map<String, String> selectedMenus) async {
    selectedMenus[dateToString(date)] = menuId;
    await prefs.setString('selectedMenus', json.encode(selectedMenus));
    await backupToFile();
  }

  // Legacy support - load old format menus
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

  // Custom times - supports date-based keys (YYYY-MM-DD-mealIdx)
  Map<String, String> loadCustomTimes() {
    final timesJson = prefs.getString('customTimes');
    if (timesJson == null) return {};
    final decoded = json.decode(timesJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  // Get custom time for a specific date and meal
  String? getCustomTimeForDate(DateTime date, int mealIdx, Map<String, String> customTimes) {
    final dateKey = '${dateToString(date)}-$mealIdx';
    if (customTimes.containsKey(dateKey)) {
      return customTimes[dateKey];
    }
    // Fall back to weekday-based key for legacy data
    final weekdayKey = '${getWeekdayIdx(date)}-$mealIdx';
    return customTimes[weekdayKey];
  }

  Future<void> saveCustomTimes(Map<String, String> times) async {
    await prefs.setString('customTimes', json.encode(times));
    await backupToFile();
  }

  Future<void> saveCustomTimeForDate(DateTime date, int mealIdx, String time, Map<String, String> customTimes) async {
    customTimes['${dateToString(date)}-$mealIdx'] = time;
    await saveCustomTimes(customTimes);
  }

  // Meal portions (YYYY-MM-DD-mealIdx -> multiplier, default 1.0)
  Map<String, double> loadMealPortions() {
    final portionsJson = prefs.getString('mealPortions');
    if (portionsJson == null) return {};
    final decoded = json.decode(portionsJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  double getPortionForDate(DateTime date, int mealIdx, Map<String, double> portions) {
    final dateKey = '${dateToString(date)}-$mealIdx';
    return portions[dateKey] ?? 1.0;
  }

  Future<void> saveMealPortions(Map<String, double> portions) async {
    await prefs.setString('mealPortions', json.encode(portions));
    await backupToFile();
  }

  Future<void> savePortionForDate(DateTime date, int mealIdx, double portion, Map<String, double> portions) async {
    final dateKey = '${dateToString(date)}-$mealIdx';
    if (portion == 1.0) {
      portions.remove(dateKey); // Don't store default value
    } else {
      portions[dateKey] = portion;
    }
    await saveMealPortions(portions);
  }

  // Settings
  bool get notificationsEnabled => prefs.getBool('notif') ?? true;
  Future<void> setNotificationsEnabled(bool value) async {
    await prefs.setBool('notif', value);
    await backupToFile();
  }

  bool get vibrationEnabled => prefs.getBool('vib') ?? true;
  Future<void> setVibrationEnabled(bool value) async {
    await prefs.setBool('vib', value);
    await backupToFile();
  }

  // Completed meals - now using date-based keys (YYYY-MM-DD-mealIdx)
  Set<String> loadCompleted() {
    return prefs.getStringList('done')?.toSet() ?? {};
  }

  // Get completion key for a specific date
  static String getCompletedKey(DateTime date, int mealIdx) {
    return '${dateToString(date)}-$mealIdx';
  }

  Future<void> saveCompleted(Set<String> completed) async {
    await prefs.setStringList('done', completed.toList());
    await backupToFile();
  }

  // Checked ingredients
  Set<String> loadCheckedIngredients() {
    return prefs.getStringList('checkedIngredients')?.toSet() ?? {};
  }

  Future<void> saveCheckedIngredients(Set<String> checked) async {
    await prefs.setStringList('checkedIngredients', checked.toList());
    await backupToFile();
  }

  // Daily drinks tracking - now using date strings (YYYY-MM-DD -> drinkId -> list of timestamps)
  Map<String, Map<String, List<String>>> loadDailyDrinksMap() {
    final drinksJson = prefs.getString('dailyDrinksV2');
    if (drinksJson == null) return {};

    try {
      final decoded = json.decode(drinksJson) as Map<String, dynamic>;
      final result = <String, Map<String, List<String>>>{};

      for (final entry in decoded.entries) {
        final dateStr = entry.key;
        final drinksMap = <String, List<String>>{};

        for (final drinkEntry in (entry.value as Map<String, dynamic>).entries) {
          final drinkId = drinkEntry.key;
          final value = drinkEntry.value;

          if (value is List) {
            drinksMap[drinkId] = value.map((t) => t as String).toList();
          }
        }

        result[dateStr] = drinksMap;
      }
      return result;
    } catch (e) {
      debugPrint('Error loading daily drinks v2, resetting: $e');
      prefs.remove('dailyDrinksV2');
      return {};
    }
  }

  Map<String, List<String>> getDrinksForDate(DateTime date, Map<String, Map<String, List<String>>> dailyDrinks) {
    return dailyDrinks[dateToString(date)] ?? {};
  }

  Future<void> saveDailyDrinksMap(Map<String, Map<String, List<String>>> dailyDrinks) async {
    await prefs.setString('dailyDrinksV2', json.encode(dailyDrinks));
    await backupToFile();
  }

  // Legacy support for old dayIdx-based drinks
  Map<int, Map<String, List<String>>> loadDailyDrinks() {
    final drinksJson = prefs.getString('dailyDrinks');
    if (drinksJson == null) return {};

    try {
      final decoded = json.decode(drinksJson) as Map<String, dynamic>;
      final result = <int, Map<String, List<String>>>{};

      for (final entry in decoded.entries) {
        final dayIdx = int.parse(entry.key);
        final drinksMap = <String, List<String>>{};

        for (final drinkEntry in (entry.value as Map<String, dynamic>).entries) {
          final drinkId = drinkEntry.key;
          final value = drinkEntry.value;

          // Migration: Handle old format (int count) vs new format (list of timestamps)
          if (value is int) {
            // Old format: convert count to list of timestamps with placeholder times
            drinksMap[drinkId] = List.generate(value, (i) => '12:00');
          } else if (value is List) {
            // New format: list of timestamps
            drinksMap[drinkId] = value.map((t) => t as String).toList();
          }
        }

        result[dayIdx] = drinksMap;
      }
      return result;
    } catch (e) {
      debugPrint('Error loading daily drinks, resetting: $e');
      // If there's an error, clear the corrupted data
      prefs.remove('dailyDrinks');
      return {};
    }
  }

  Future<void> saveDailyDrinks(Map<int, Map<String, List<String>>> dailyDrinks) async {
    final encoded = dailyDrinks.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('dailyDrinks', json.encode(encoded));
  }

  // Daily snacks tracking - dateStr -> snackId -> list of {timestamp, portion}
  Map<String, Map<String, List<Map<String, dynamic>>>> loadDailySnacksMap() {
    final snacksJson = prefs.getString('dailySnacks');
    if (snacksJson == null) return {};

    try {
      final decoded = json.decode(snacksJson) as Map<String, dynamic>;
      final result = <String, Map<String, List<Map<String, dynamic>>>>{};

      for (final entry in decoded.entries) {
        final dateStr = entry.key;
        final snacksMap = <String, List<Map<String, dynamic>>>{};

        for (final snackEntry in (entry.value as Map<String, dynamic>).entries) {
          final snackId = snackEntry.key;
          final value = snackEntry.value;

          if (value is List) {
            snacksMap[snackId] = value.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              // Legacy support: if it's just a string timestamp
              return {'timestamp': item.toString(), 'portion': 1.0};
            }).toList();
          }
        }

        result[dateStr] = snacksMap;
      }
      return result;
    } catch (e) {
      debugPrint('Error loading daily snacks, resetting: $e');
      prefs.remove('dailySnacks');
      return {};
    }
  }

  Map<String, List<Map<String, dynamic>>> getSnacksForDate(
      DateTime date, Map<String, Map<String, List<Map<String, dynamic>>>> dailySnacks) {
    return dailySnacks[dateToString(date)] ?? {};
  }

  Future<void> saveDailySnacksMap(Map<String, Map<String, List<Map<String, dynamic>>>> dailySnacks) async {
    await prefs.setString('dailySnacks', json.encode(dailySnacks));
    await backupToFile();
  }

  // Daily water tracking - dateStr -> list of {timestamp, ml}
  Map<String, List<Map<String, dynamic>>> loadDailyWater() {
    final waterJson = prefs.getString('dailyWater');
    if (waterJson == null) return {};

    try {
      final decoded = json.decode(waterJson) as Map<String, dynamic>;
      final result = <String, List<Map<String, dynamic>>>{};

      for (final entry in decoded.entries) {
        final dateStr = entry.key;
        final value = entry.value;

        // Migration: Handle old format (int total) vs new format (list of entries)
        if (value is int) {
          // Old format: convert to a single entry with placeholder time
          result[dateStr] = [{'timestamp': '12:00', 'ml': value}];
        } else if (value is List) {
          // New format: list of {timestamp, ml}
          result[dateStr] = value.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return {'timestamp': '12:00', 'ml': 0};
          }).toList();
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error loading daily water, resetting: $e');
      prefs.remove('dailyWater');
      return {};
    }
  }

  int getWaterForDate(DateTime date, Map<String, List<Map<String, dynamic>>> dailyWater) {
    final entries = dailyWater[dateToString(date)] ?? [];
    return entries.fold(0, (sum, entry) => sum + ((entry['ml'] as num?)?.toInt() ?? 0));
  }

  Future<void> saveDailyWater(Map<String, List<Map<String, dynamic>>> dailyWater) async {
    await prefs.setString('dailyWater', json.encode(dailyWater));
    await backupToFile();
  }

  // Daily liquids tracking (energy drinks, milk, etc.) - dateStr -> liquidId -> list of {timestamp, ml, macros}
  Map<String, Map<String, List<Map<String, dynamic>>>> loadDailyLiquids() {
    final liquidsJson = prefs.getString('dailyLiquids');
    if (liquidsJson == null) return {};

    try {
      final decoded = json.decode(liquidsJson) as Map<String, dynamic>;
      final result = <String, Map<String, List<Map<String, dynamic>>>>{};

      for (final entry in decoded.entries) {
        final dateStr = entry.key;
        final liquidsMap = <String, List<Map<String, dynamic>>>{};

        for (final liquidEntry in (entry.value as Map<String, dynamic>).entries) {
          final liquidId = liquidEntry.key;
          final value = liquidEntry.value;

          if (value is List) {
            liquidsMap[liquidId] = value.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return {'timestamp': item.toString(), 'ml': 0};
            }).toList();
          }
        }

        result[dateStr] = liquidsMap;
      }
      return result;
    } catch (e) {
      debugPrint('Error loading daily liquids, resetting: $e');
      prefs.remove('dailyLiquids');
      return {};
    }
  }

  Map<String, List<Map<String, dynamic>>> getLiquidsForDate(
      DateTime date, Map<String, Map<String, List<Map<String, dynamic>>>> dailyLiquids) {
    return dailyLiquids[dateToString(date)] ?? {};
  }

  Future<void> saveDailyLiquids(Map<String, Map<String, List<Map<String, dynamic>>>> dailyLiquids) async {
    await prefs.setString('dailyLiquids', json.encode(dailyLiquids));
    await backupToFile();
  }
}
