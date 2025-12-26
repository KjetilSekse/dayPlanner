import 'recipe.dart';

class Snack {
  final String id;
  final String name;
  final Macros per100g;
  final double servingGrams; // Size of one serving in grams
  final List<String>? ingredients; // Optional
  final List<String>? instructions; // Optional

  const Snack({
    required this.id,
    required this.name,
    required this.per100g,
    required this.servingGrams,
    this.ingredients,
    this.instructions,
  });

  bool get hasRecipe => ingredients != null && ingredients!.isNotEmpty;

  // Dynamically calculate per serving macros from per_100g
  Macros get perServing {
    final multiplier = servingGrams / 100;
    return Macros(
      cals: (double.parse(per100g.cals) * multiplier).round().toString(),
      carbs: (double.parse(per100g.carbs) * multiplier).toStringAsFixed(1),
      fat: (double.parse(per100g.fat) * multiplier).toStringAsFixed(1),
      protein: (double.parse(per100g.protein) * multiplier).toStringAsFixed(1),
    );
  }

  factory Snack.fromJson(String id, Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>;
    return Snack(
      id: id,
      name: json['name'] as String,
      per100g: Macros.fromJson(macros['per_100g'] as Map<String, dynamic>),
      servingGrams: (json['serving_grams'] as num).toDouble(),
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'] as List)
          : null,
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'] as List)
          : null,
    );
  }

  // Calculate total macros for a given portion multiplier
  Macros getTotalForPortion(double portion) {
    final serving = perServing;
    return Macros(
      cals: (double.parse(serving.cals) * portion).round().toString(),
      carbs: (double.parse(serving.carbs) * portion).toStringAsFixed(1),
      fat: (double.parse(serving.fat) * portion).toStringAsFixed(1),
      protein: (double.parse(serving.protein) * portion).toStringAsFixed(1),
    );
  }
}
