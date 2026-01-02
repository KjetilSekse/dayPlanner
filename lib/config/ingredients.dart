/// Ingredients configuration for "Construct Meal" feature
/// All macros are per 100g for easy scaling

class IngredientMacros {
  final int calories;
  final double fat;
  final double carbs;
  final double protein;

  const IngredientMacros({
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
  });

  /// Scale macros by grams (returns macros for given amount)
  IngredientMacros scaleToGrams(double grams) {
    final factor = grams / 100;
    return IngredientMacros(
      calories: (calories * factor).round(),
      fat: fat * factor,
      carbs: carbs * factor,
      protein: protein * factor,
    );
  }

  /// Add two macro values together
  IngredientMacros operator +(IngredientMacros other) {
    return IngredientMacros(
      calories: calories + other.calories,
      fat: fat + other.fat,
      carbs: carbs + other.carbs,
      protein: protein + other.protein,
    );
  }
}

class Ingredient {
  final String id;
  final String name;
  final double defaultGrams; // Suggested portion
  final IngredientMacros per100g;

  const Ingredient({
    required this.id,
    required this.name,
    required this.defaultGrams,
    required this.per100g,
  });

  /// Get macros for default portion
  IngredientMacros get macrosForDefault => per100g.scaleToGrams(defaultGrams);

  /// Get macros for custom portion
  IngredientMacros macrosForGrams(double grams) => per100g.scaleToGrams(grams);
}

class IngredientCategory {
  final String name;
  final String icon;
  final List<Ingredient> items;

  const IngredientCategory({
    required this.name,
    required this.icon,
    required this.items,
  });
}

// ============== INGREDIENT CATEGORIES ==============
// Add your ingredients here, organized by category
// All macros are per 100g

const List<IngredientCategory> ingredientCategories = [
  // Example categories - user will populate with actual data
  IngredientCategory(
    name: 'Proteins',
    icon: '🥩',
    items: [
      // Example: Chicken Breast: 165 kcal, 3.6g fat, 0g carbs, 31g protein per 100g
      // Ingredient(
      //   id: 'chicken_breast',
      //   name: 'Chicken Breast',
      //   defaultGrams: 150,
      //   per100g: IngredientMacros(calories: 165, fat: 3.6, carbs: 0, protein: 31),
      // ),
    ],
  ),
  IngredientCategory(
    name: 'Dairy',
    icon: '🥛',
    items: [
      // Vanilla Sauce: 150 kcal, 8.4g fat, 16g carbs, 2.8g protein per 100g
      Ingredient(
        id: 'vanilla_sauce',
        name: 'Vanilla Sauce',
        defaultGrams: 50,
        per100g: IngredientMacros(calories: 150, fat: 8.4, carbs: 16, protein: 2.8),
      ),
    ],
  ),
  IngredientCategory(
    name: 'Grains',
    icon: '🌾',
    items: [],
  ),
  IngredientCategory(
    name: 'Fruits',
    icon: '🍎',
    items: [],
  ),
  IngredientCategory(
    name: 'Vegetables',
    icon: '🥬',
    items: [
      // Gratinated Potatoes: ~111 kcal, 6g fat, 12g carbs, 2.3g protein per 100g
      Ingredient(
        id: 'gratinated_potatoes',
        name: 'Gratinated Potatoes',
        defaultGrams: 150,
        per100g: IngredientMacros(calories: 111, fat: 6.0, carbs: 12, protein: 2.3),
      ),
      // Asparagus: ~18 kcal, 0.1g fat, 2.2g carbs, 2g protein per 100g
      Ingredient(
        id: 'asparagus',
        name: 'Asparagus',
        defaultGrams: 100,
        per100g: IngredientMacros(calories: 18, fat: 0.1, carbs: 2.2, protein: 2),
      ),
    ],
  ),
  IngredientCategory(
    name: 'Fats & Oils',
    icon: '🫒',
    items: [],
  ),
  IngredientCategory(
    name: 'Other',
    icon: '🍽️',
    items: [],
  ),
];

// Flat list of all ingredients (for lookup helpers)
List<Ingredient> get allIngredients =>
    ingredientCategories.expand((cat) => cat.items).toList();

// ============== LOOKUP HELPERS ==============

Ingredient? getIngredientById(String id) {
  try {
    return allIngredients.firstWhere((i) => i.id == id);
  } catch (_) {
    return null;
  }
}
