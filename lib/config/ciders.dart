import '../models/recipe.dart';

/// Cider configuration - define ciders here instead of individual JSON files
/// All Halmstad Crush ciders are 500ml cans with same base macros

class CiderVariant {
  final String id;
  final String name;
  final int mlPerCan;
  final int calsPerCan;
  final double carbsPerCan;
  final double fatPerCan;
  final double proteinPerCan;

  const CiderVariant({
    required this.id,
    required this.name,
    this.mlPerCan = 500,
    required this.calsPerCan,
    required this.carbsPerCan,
    this.fatPerCan = 0,
    this.proteinPerCan = 0,
  });

  /// Convert to Recipe for use in drinks system
  Recipe toRecipe() {
    final per100 = mlPerCan / 100;
    return Recipe(
      id: id,
      name: name,
      ingredients: [
        '1 can (${mlPerCan}ml) $name',
        'Ice cubes (optional)',
      ],
      instructions: [
        'Chill the can in the refrigerator.',
        'Pour into a glass over ice if desired.',
        'Enjoy cold.',
      ],
      per100g: Macros(
        cals: '${(calsPerCan / per100).round()} kcal',
        carbs: '${(carbsPerCan / per100).toStringAsFixed(1)} g',
        fat: '${(fatPerCan / per100).toStringAsFixed(1)} g',
        protein: '${(proteinPerCan / per100).toStringAsFixed(1)} g',
      ),
      total: Macros(
        cals: '$calsPerCan kcal',
        carbs: '${carbsPerCan.toStringAsFixed(1)} g',
        fat: '${fatPerCan.toStringAsFixed(1)} g',
        protein: '${proteinPerCan.toStringAsFixed(1)} g',
      ),
      servingGrams: mlPerCan.toDouble(),
    );
  }
}

// ============== HALMSTAD CRUSH CIDERS ==============
// All 500ml cans

const List<CiderVariant> halmstadCrushCiders = [
  // Base Halmstad Crush - 150 cals, 5g carbs per 500ml
  CiderVariant(
    id: 'halmstad_crush_passion',
    name: 'Halmstad Crush Cloudy Mango & Passion Fruit',
    calsPerCan: 355,
    carbsPerCan: 40,
  ),
  CiderVariant(
    id: 'halmstad_crush_tropical_fruit_punch',
    name: 'Halmstad Crush Cloudy Tropical Fruit Punch',
    calsPerCan: 315,
    carbsPerCan: 34,
  ),
  // Add more flavors here as needed:
  // CiderVariant(
  //   id: 'halmstad_crush_raspberry',
  //   name: 'Halmstad Crush Raspberry',
  //   calsPerCan: 150,
  //   carbsPerCan: 5,
  // ),
];

// ============== OTHER CIDERS ==============
// Add other cider brands here

const List<CiderVariant> otherCiders = [
  // Example:
  // CiderVariant(
  //   id: 'sommersby_apple',
  //   name: 'Somersby Apple',
  //   mlPerCan: 330,
  //   calsPerCan: 140,
  //   carbsPerCan: 12,
  // ),
];

// ============== ALL CIDERS ==============

List<CiderVariant> get allCiders => [
  ...halmstadCrushCiders,
  ...otherCiders,
];

/// Get all ciders as Recipe map (for integration with drinks system)
Map<String, Recipe> getCiderRecipes() {
  final recipes = <String, Recipe>{};
  for (final cider in allCiders) {
    recipes[cider.id] = cider.toRecipe();
  }
  return recipes;
}

// ============== MISC ITEMS ==============
// Non-drink items tracked through drinks system

final Recipe snusRecipe = Recipe(
  id: 'snus',
  name: 'Snus',
  ingredients: ['1 portion snus'],
  instructions: ['Place under upper lip.'],
  per100g: Macros(cals: '0 kcal', carbs: '0 g', fat: '0 g', protein: '0 g'),
  total: Macros(cals: '0 kcal', carbs: '0 g', fat: '0 g', protein: '0 g'),
  servingGrams: 1,
);

/// Get misc items as Recipe map
Map<String, Recipe> getMiscRecipes() {
  return {
    'snus': snusRecipe,
  };
}
