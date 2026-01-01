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

// ============== TOPPINGS ==============

const List<Topping> toppings = [
  // Strandaskinke: 239 kcal, 14g fat, 0g carbs, 28g protein per 100g
  // Default 15g per slice
  Topping(
    id: 'strandaskinke',
    name: 'Strandaskinke',
    defaultGrams: 15,
    per100g: BreadMacros(calories: 239, fat: 14, carbs: 0, protein: 28),
  ),
  // Potato Salad (Rema 1000): 237 kcal, 21.7g fat, 9.6g carbs, 1g protein per 100g
  // Default 45g per slice
  Topping(
    id: 'potato_salad',
    name: 'Potato Salad (Rema)',
    defaultGrams: 45,
    per100g: BreadMacros(calories: 237, fat: 21.7, carbs: 9.6, protein: 1),
  ),
  // Sriracha: ~93 kcal, 0g fat, 20g carbs, 1g protein per 100g
  // Default 15g per slice
  Topping(
    id: 'sriracha',
    name: 'Sriracha',
    defaultGrams: 15,
    per100g: BreadMacros(calories: 93, fat: 0, carbs: 20, protein: 1),
  ),
  // Smoked Salmon: 234 kcal, 17g fat, 0.8g carbs, 20g protein per 100g
  // Default 20g per slice
  Topping(
    id: 'smoked_salmon',
    name: 'Smoked Salmon',
    defaultGrams: 20,
    per100g: BreadMacros(calories: 234, fat: 17, carbs: 0.8, protein: 20),
  ),
];

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
