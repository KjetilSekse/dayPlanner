import 'dart:convert';
import '../config/ingredients.dart';

/// Represents a single ingredient item added to a meal with custom gram amount
class MealItem {
  final String ingredientId;
  final double grams;

  const MealItem({
    required this.ingredientId,
    required this.grams,
  });

  /// Get the ingredient definition (or null if not found)
  Ingredient? get ingredient => getIngredientById(ingredientId);

  /// Calculate macros for this item's gram amount
  IngredientMacros? get macros {
    final ing = ingredient;
    if (ing == null) return null;
    return ing.macrosForGrams(grams);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'grams': grams,
  };

  /// Create from JSON
  factory MealItem.fromJson(Map<String, dynamic> json) => MealItem(
    ingredientId: json['ingredientId'] as String,
    grams: (json['grams'] as num).toDouble(),
  );

  /// Encode to a storable ID string (format: "item:base64data")
  String toEncodedId() {
    final jsonStr = jsonEncode(toJson());
    final base64Str = base64Encode(utf8.encode(jsonStr));
    return 'item:$base64Str';
  }

  /// Decode from an encoded ID string
  static MealItem? fromEncodedId(String encodedId) {
    if (!encodedId.startsWith('item:')) return null;
    try {
      final base64Str = encodedId.substring(5); // Remove 'item:' prefix
      final jsonStr = utf8.decode(base64Decode(base64Str));
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MealItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Check if a string is an encoded MealItem ID
  static bool isEncodedMealItem(String id) => id.startsWith('item:');

  @override
  String toString() => 'MealItem($ingredientId, ${grams}g)';
}
