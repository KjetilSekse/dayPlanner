/// Bread and topping configuration for "Bread with Topping" meals
/// All macros are per 100g for easy scaling

class BreadMacros {
  final int calories;
  final double fat;
  final double carbs;
  final double protein;

  const BreadMacros({
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.protein,
  });

  /// Scale macros by grams (returns macros for given amount)
  BreadMacros scaleToGrams(double grams) {
    final factor = grams / 100;
    return BreadMacros(
      calories: (calories * factor).round(),
      fat: fat * factor,
      carbs: carbs * factor,
      protein: protein * factor,
    );
  }

  /// Add two macro values together
  BreadMacros operator +(BreadMacros other) {
    return BreadMacros(
      calories: calories + other.calories,
      fat: fat + other.fat,
      carbs: carbs + other.carbs,
      protein: protein + other.protein,
    );
  }
}

class Bread {
  final String id;
  final String name;
  final double gramsPerUnit; // Weight of one bread/roll/slice
  final BreadMacros per100g;

  const Bread({
    required this.id,
    required this.name,
    required this.gramsPerUnit,
    required this.per100g,
  });

  /// Get macros for one unit of bread
  BreadMacros get macrosPerUnit => per100g.scaleToGrams(gramsPerUnit);
}

class Topping {
  final String id;
  final String name;
  final double defaultGrams; // Suggested portion
  final BreadMacros per100g;

  const Topping({
    required this.id,
    required this.name,
    required this.defaultGrams,
    required this.per100g,
  });

  /// Get macros for default portion
  BreadMacros get macrosForDefault => per100g.scaleToGrams(defaultGrams);

  /// Get macros for custom portion
  BreadMacros macrosForGrams(double grams) => per100g.scaleToGrams(grams);
}

class ToppingCategory {
  final String name;
  final String icon;
  final List<Topping> items;

  const ToppingCategory({
    required this.name,
    required this.icon,
    required this.items,
  });
}

/// Preset combination for quick selection
class BreadPreset {
  final String id;
  final String name;
  final String breadId;
  final int breadCount; // Number of bread units
  final List<ToppingPortion> toppings;

  const BreadPreset({
    required this.id,
    required this.name,
    required this.breadId,
    this.breadCount = 1,
    required this.toppings,
  });
}

class ToppingPortion {
  final String toppingId;
  final double grams;

  const ToppingPortion(this.toppingId, this.grams);
}

// ============== BREADS ==============

const List<Bread> breads = [
  // Sesame Seed Breadroll: 286 kcal, 4.8g fat, 50g carbs, 8.8g protein per 100g
  // 60g per roll
  Bread(
    id: 'sesame_roll',
    name: 'Sesame Seed Roll',
    gramsPerUnit: 60,
    per100g: BreadMacros(calories: 286, fat: 4.8, carbs: 50, protein: 8.8),
  ),
  // Brioche: 330 kcal, 10g fat, 53g carbs, 8g protein per 100g
  // 35g per slice
  Bread(
    id: 'brioche',
    name: 'Brioche',
    gramsPerUnit: 35,
    per100g: BreadMacros(calories: 330, fat: 10, carbs: 53, protein: 8),
  ),
];

// ============== TOPPING CATEGORIES ==============

const List<ToppingCategory> toppingCategories = [
  // Meats
  ToppingCategory(
    name: 'Meats',
    icon: '🥩',
    items: [
      // Strandaskinke: 239 kcal, 14g fat, 0g carbs, 28g protein per 100g
      Topping(
        id: 'strandaskinke',
        name: 'Strandaskinke',
        defaultGrams: 15,
        per100g: BreadMacros(calories: 239, fat: 14, carbs: 0, protein: 28),
      ),
      // Smoked Salmon: 234 kcal, 17g fat, 0.8g carbs, 20g protein per 100g
      Topping(
        id: 'smoked_salmon',
        name: 'Smoked Salmon',
        defaultGrams: 20,
        per100g: BreadMacros(calories: 234, fat: 17, carbs: 0.8, protein: 20),
      ),
      // Roastbeef: 104 kcal, 1.5g fat, 1.6g carbs, 21g protein per 100g
      Topping(
        id: 'roastbeef',
        name: 'Roastbeef',
        defaultGrams: 15,
        per100g: BreadMacros(calories: 104, fat: 1.5, carbs: 1.6, protein: 21),
      ),
      // Dried Lamb Thigh (Fenalår): 229 kcal, 13g fat, 0g carbs, 28g protein per 100g
      Topping(
        id: 'dried_lamb_thigh',
        name: 'Dried Lamb Thigh',
        defaultGrams: 15,
        per100g: BreadMacros(calories: 229, fat: 13, carbs: 0, protein: 28),
      ),
    ],
  ),
  // Sauces & Spreads
  ToppingCategory(
    name: 'Sauces & Spreads',
    icon: '🥫',
    items: [
      // Sriracha: ~93 kcal, 0g fat, 20g carbs, 1g protein per 100g
      Topping(
        id: 'sriracha',
        name: 'Sriracha',
        defaultGrams: 15,
        per100g: BreadMacros(calories: 93, fat: 0, carbs: 20, protein: 1),
      ),
      // Potato Salad (Rema 1000): 237 kcal, 21.7g fat, 9.6g carbs, 1g protein per 100g
      Topping(
        id: 'potato_salad',
        name: 'Potato Salad (Rema)',
        defaultGrams: 45,
        per100g: BreadMacros(calories: 237, fat: 21.7, carbs: 9.6, protein: 1),
      ),
    ],
  ),
  // Other
  ToppingCategory(
    name: 'Other',
    icon: '🍳',
    items: [
      // Scrambled Eggs Lean: 1 egg (60g) + 10g lettmelk = 70g total
      // Per 100g: 133 kcal, 9.3g fat, 1g carbs, 11.7g protein
      Topping(
        id: 'scrambled_eggs_lean',
        name: 'Scrambled Eggs (Lean)',
        defaultGrams: 70,
        per100g: BreadMacros(calories: 133, fat: 9.3, carbs: 1, protein: 11.7),
      ),
      // Scrambled Eggs Gourmet: 1 egg (60g) + 15g cream + 3.5g butter = 78.5g total
      // Per 100g: 214 kcal, 19g fat, 0.8g carbs, 10.3g protein
      Topping(
        id: 'scrambled_eggs_gourmet',
        name: 'Scrambled Eggs (Gourmet)',
        defaultGrams: 79,
        per100g: BreadMacros(calories: 214, fat: 19, carbs: 0.8, protein: 10.3),
      ),
      // Avocado: 191 kcal, 19.6g fat, 0.4g carbs, 1.8g protein per 100g
      Topping(
        id: 'avocado',
        name: 'Avocado',
        defaultGrams: 30,
        per100g: BreadMacros(calories: 191, fat: 19.6, carbs: 0.4, protein: 1.8),
      ),
    ],
  ),
];

// Flat list of all toppings (for lookup helpers)
List<Topping> get toppings =>
    toppingCategories.expand((cat) => cat.items).toList();

// ============== PRESETS ==============
// Add commonly used combinations here

const List<BreadPreset> breadPresets = [
  // Example: 2 rolls with 30g ham each
  // BreadPreset(
  //   id: 'double_ham_rolls',
  //   name: '2 Ham Rolls',
  //   breadId: 'sesame_roll',
  //   breadCount: 2,
  //   toppings: [ToppingPortion('strandaskinke', 60)],
  // ),
];

// ============== LOOKUP HELPERS ==============

Bread? getBreadById(String id) {
  try {
    return breads.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
}

Topping? getToppingById(String id) {
  try {
    return toppings.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

BreadPreset? getPresetById(String id) {
  try {
    return breadPresets.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}
