class Macros {
  final String cals;
  final String carbs;
  final String fat;
  final String protein;

  const Macros({
    required this.cals,
    required this.carbs,
    required this.fat,
    required this.protein,
  });

  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
      cals: json['cals'] as String,
      carbs: json['carbs'] as String,
      fat: json['fat'] as String,
      protein: json['protein'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'cals': cals,
    'carbs': carbs,
    'fat': fat,
    'protein': protein,
  };
}

class Recipe {
  final String id;
  final String name;
  final List<String> ingredients;
  final List<String> instructions;
  final Macros per100g;
  final Macros total;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    required this.per100g,
    required this.total,
  });

  factory Recipe.fromJson(String id, Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>;
    return Recipe(
      id: id,
      name: json['name'] as String,
      ingredients: List<String>.from(json['ingredients'] as List),
      instructions: List<String>.from(json['instructions'] as List),
      per100g: Macros.fromJson(macros['per_100g'] as Map<String, dynamic>),
      total: Macros.fromJson(macros['total'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'ingredients': ingredients,
    'instructions': instructions,
    'macros': {
      'per_100g': per100g.toJson(),
      'total': total.toJson(),
    },
  };
}
