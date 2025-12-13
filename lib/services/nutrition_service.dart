import '../models/recipe.dart';
import 'storage_service.dart';

/// Daily nutrition summary
class DailyMacros {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const DailyMacros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const zero = DailyMacros(calories: 0, protein: 0, carbs: 0, fat: 0);

  DailyMacros operator +(DailyMacros other) {
    return DailyMacros(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
    );
  }

  DailyMacros multiply(double factor) {
    return DailyMacros(
      calories: (calories * factor).round(),
      protein: (protein * factor).round(),
      carbs: (carbs * factor).round(),
      fat: (fat * factor).round(),
    );
  }
}

/// Service for querying nutrition data across dates
/// Designed for future analytics (graphs, trends, etc.)
class NutritionService {
  final Map<String, Recipe> recipes;
  final Map<MealCategory, Map<String, Recipe>> categoryRecipes;
  final Map<String, Recipe> drinks;
  final Map<String, String> mealReplacements;
  final Map<String, double> mealPortions;
  final Map<String, Map<String, List<String>>> dailyDrinks;

  NutritionService({
    required this.recipes,
    required this.categoryRecipes,
    required this.drinks,
    required this.mealReplacements,
    required this.mealPortions,
    required this.dailyDrinks,
  });

  /// Find recipe by ID across all recipe sources
  Recipe? findRecipe(String recipeId) {
    if (recipes.containsKey(recipeId)) {
      return recipes[recipeId];
    }
    for (final categoryMap in categoryRecipes.values) {
      if (categoryMap.containsKey(recipeId)) {
        return categoryMap[recipeId];
      }
    }
    return null;
  }

  /// Get recipe for a specific date and meal
  Recipe? getRecipeForMeal(DateTime date, int mealIdx) {
    // Check date-specific replacement first
    final dateKey = '${StorageService.dateToString(date)}-$mealIdx';
    if (mealReplacements.containsKey(dateKey)) {
      return findRecipe(mealReplacements[dateKey]!);
    }
    // Fall back to weekday default
    final weekdayKey = '${StorageService.getWeekdayIdx(date)}-$mealIdx';
    if (mealReplacements.containsKey(weekdayKey)) {
      return findRecipe(mealReplacements[weekdayKey]!);
    }
    return null;
  }

  /// Get portion multiplier for a specific date and meal
  double getPortionForMeal(DateTime date, int mealIdx) {
    final dateKey = '${StorageService.dateToString(date)}-$mealIdx';
    return mealPortions[dateKey] ?? 1.0;
  }

  /// Parse a macro value string like "410 kcal" or "45 g" to a number
  static int _parseValue(String value) {
    final numStr = value.split(' ').first;
    return double.tryParse(numStr)?.round() ?? 0;
  }

  /// Parse macros from recipe (handles string values with units)
  DailyMacros _parseMacros(Macros macros) {
    return DailyMacros(
      calories: _parseValue(macros.cals),
      protein: _parseValue(macros.protein),
      carbs: _parseValue(macros.carbs),
      fat: _parseValue(macros.fat),
    );
  }

  /// Get total calories for a single date
  int getCaloriesForDate(DateTime date) {
    return getMacrosForDate(date).calories;
  }

  /// Get full macros for a single date
  DailyMacros getMacrosForDate(DateTime date) {
    DailyMacros total = DailyMacros.zero;

    // Add meals (breakfast=0, lunch=1, dinner=2)
    for (int mealIdx = 0; mealIdx < 3; mealIdx++) {
      final recipe = getRecipeForMeal(date, mealIdx);
      if (recipe != null) {
        final portion = getPortionForMeal(date, mealIdx);
        final mealMacros = _parseMacros(recipe.total);
        total = total + mealMacros.multiply(portion);
      }
    }

    // Add drinks
    final dateStr = StorageService.dateToString(date);
    final dateDrinks = dailyDrinks[dateStr] ?? {};
    for (final entry in dateDrinks.entries) {
      final drinkId = entry.key;
      final timestamps = entry.value;
      final drink = drinks[drinkId];
      if (drink != null) {
        final drinkMacros = _parseMacros(drink.total);
        // Multiply by number of drinks
        total = total + drinkMacros.multiply(timestamps.length.toDouble());
      }
    }

    return total;
  }

  /// Get calories for a date range (for analytics/graphs)
  Map<DateTime, int> getCaloriesForRange(DateTime start, DateTime end) {
    final result = <DateTime, int>{};
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      result[current] = getCaloriesForDate(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get full macros for a date range (for detailed analytics)
  Map<DateTime, DailyMacros> getMacrosForRange(DateTime start, DateTime end) {
    final result = <DateTime, DailyMacros>{};
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      result[current] = getMacrosForDate(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Get average daily calories for a date range
  double getAverageCaloriesForRange(DateTime start, DateTime end) {
    final calories = getCaloriesForRange(start, end);
    if (calories.isEmpty) return 0;
    final total = calories.values.fold(0, (sum, cal) => sum + cal);
    return total / calories.length;
  }
}
