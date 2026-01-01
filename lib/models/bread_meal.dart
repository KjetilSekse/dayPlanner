import 'dart:convert';
import '../config/bread_toppings.dart';
import 'recipe.dart';

/// A user-configured bread meal with selected bread and toppings
class BreadMeal {
  final String breadId;
  final int breadCount;
  final List<SelectedTopping> toppings;

  const BreadMeal({
    required this.breadId,
    this.breadCount = 1,
    required this.toppings,
  });

  /// Create from JSON
  factory BreadMeal.fromJson(Map<String, dynamic> json) {
    return BreadMeal(
      breadId: json['breadId'] as String,
      breadCount: json['breadCount'] as int? ?? 1,
      toppings: (json['toppings'] as List<dynamic>)
          .map((t) => SelectedTopping.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'breadId': breadId,
        'breadCount': breadCount,
        'toppings': toppings.map((t) => t.toJson()).toList(),
      };

  /// Encode to a string for use as a recipe ID
  String toEncodedId() => 'bread:${base64Encode(utf8.encode(jsonEncode(toJson())))}';

  /// Decode from an encoded recipe ID
  static BreadMeal? fromEncodedId(String encodedId) {
    if (!encodedId.startsWith('bread:')) return null;
    try {
      final jsonStr = utf8.decode(base64Decode(encodedId.substring(6)));
      return BreadMeal.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Check if a recipe ID is a bread meal
  static bool isBreadMealId(String recipeId) => recipeId.startsWith('bread:');

  /// Calculate total macros for this bread meal
  BreadMacros? calculateTotalMacros() {
    final bread = getBreadById(breadId);
    if (bread == null) return null;

    // Start with bread macros
    BreadMacros total = BreadMacros(calories: 0, fat: 0, carbs: 0, protein: 0);

    // Add bread (count * macros per unit)
    final breadMacros = bread.macrosPerUnit;
    for (int i = 0; i < breadCount; i++) {
      total = total + breadMacros;
    }

    // Add each topping
    for (final selectedTopping in toppings) {
      final topping = getToppingById(selectedTopping.toppingId);
      if (topping != null) {
        total = total + topping.macrosForGrams(selectedTopping.grams);
      }
    }

    return total;
  }

  /// Calculate total weight in grams
  double calculateTotalWeight() {
    final bread = getBreadById(breadId);
    if (bread == null) return 0;

    double total = bread.gramsPerUnit * breadCount;

    for (final selectedTopping in toppings) {
      total += selectedTopping.grams;
    }

    return total;
  }

  /// Generate a display name
  String generateName() {
    final bread = getBreadById(breadId);
    if (bread == null) return 'Bread with Topping';

    final toppingNames = toppings
        .map((t) => getToppingById(t.toppingId)?.name ?? 'Unknown')
        .toList();

    if (toppingNames.isEmpty) {
      return breadCount > 1 ? '$breadCount x ${bread.name}' : bread.name;
    }

    final toppingStr = toppingNames.join(', ');
    if (breadCount > 1) {
      return '$breadCount x ${bread.name} with $toppingStr';
    }
    return '${bread.name} with $toppingStr';
  }

  /// Generate ingredient list
  List<String> generateIngredients() {
    final ingredients = <String>[];
    final bread = getBreadById(breadId);

    if (bread != null) {
      final totalBreadGrams = bread.gramsPerUnit * breadCount;
      ingredients.add('${totalBreadGrams.toStringAsFixed(0)}g ${bread.name} ($breadCount ${breadCount == 1 ? "piece" : "pieces"})');
    }

    for (final selectedTopping in toppings) {
      final topping = getToppingById(selectedTopping.toppingId);
      if (topping != null) {
        ingredients.add('${selectedTopping.grams.toStringAsFixed(0)}g ${topping.name}');
      }
    }

    return ingredients;
  }

  /// Convert to a Recipe object for display
  Recipe? toRecipe() {
    final macros = calculateTotalMacros();
    if (macros == null) return null;

    final totalWeight = calculateTotalWeight();
    final per100gFactor = totalWeight > 0 ? 100 / totalWeight : 1;

    final per100gMacros = BreadMacros(
      calories: (macros.calories * per100gFactor).round(),
      fat: macros.fat * per100gFactor,
      carbs: macros.carbs * per100gFactor,
      protein: macros.protein * per100gFactor,
    );

    return Recipe(
      id: toEncodedId(),
      name: generateName(),
      ingredients: generateIngredients(),
      instructions: ['Prepare bread with toppings and enjoy!'],
      per100g: Macros(
        cals: '${per100gMacros.calories} kcal',
        fat: '${per100gMacros.fat.toStringAsFixed(1)} g',
        carbs: '${per100gMacros.carbs.toStringAsFixed(1)} g',
        protein: '${per100gMacros.protein.toStringAsFixed(1)} g',
      ),
      total: Macros(
        cals: '${macros.calories} kcal',
        fat: '${macros.fat.toStringAsFixed(1)} g',
        carbs: '${macros.carbs.toStringAsFixed(1)} g',
        protein: '${macros.protein.toStringAsFixed(1)} g',
      ),
      servingGrams: totalWeight,
    );
  }
}

/// A topping with a specific gram amount
class SelectedTopping {
  final String toppingId;
  final double grams;

  const SelectedTopping({
    required this.toppingId,
    required this.grams,
  });

  factory SelectedTopping.fromJson(Map<String, dynamic> json) {
    return SelectedTopping(
      toppingId: json['toppingId'] as String,
      grams: (json['grams'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'toppingId': toppingId,
        'grams': grams,
      };
}
