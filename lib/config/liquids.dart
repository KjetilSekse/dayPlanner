/// Liquid configuration for the Liquids tab
/// Macros are optional - null means no calorie/macro tracking

class LiquidMacros {
  final int calories;
  final double fat;
  final double carbs;
  final double protein;

  const LiquidMacros({
    required this.calories,
    this.fat = 0,
    this.carbs = 0,
    this.protein = 0,
  });

  // Shorthand for calorie-only
  const LiquidMacros.cals(this.calories)
      : fat = 0,
        carbs = 0,
        protein = 0;
}

class Liquid {
  final String name;
  final int ml;
  final LiquidMacros? macros; // Optional - null for zero/negligible calories

  const Liquid(this.name, this.ml, [this.macros]);
}

class LiquidCategory {
  final String name;
  final String icon;
  final List<Liquid> items;

  const LiquidCategory({
    required this.name,
    required this.icon,
    required this.items,
  });
}

const List<LiquidCategory> liquidCategories = [
  // Dairy & Juice
  LiquidCategory(
    name: 'Milk & Juice',
    icon: '🥛',
    items: [
      // 1% fat milk: 41 kcal, 1g fat, 4.5g carbs, 3.5g protein per 100ml
      // 250ml: 103 kcal, 2.5g fat, 11.3g carbs, 8.8g protein
      Liquid('1% Fat Milk (Ekstra Lett)', 250, LiquidMacros(calories: 103, fat: 2.5, carbs: 11.3, protein: 8.8)),
      // Whole milk: 63 kcal, 3.5g fat, 4.5g carbs, 3.4g protein per 100ml
      // 250ml: 158 kcal, 8.8g fat, 11.3g carbs, 8.5g protein
      Liquid('Whole Milk (Helmelk)', 250, LiquidMacros(calories: 158, fat: 8.8, carbs: 11.3, protein: 8.5)),
      // Orange juice: 36 kcal, 0.1g fat, 8.3g carbs, 0.5g protein per 100ml
      // 250ml: 90 kcal, 0.3g fat, 20.8g carbs, 1.3g protein
      Liquid('Orange Juice', 250, LiquidMacros(calories: 90, fat: 0.3, carbs: 20.8, protein: 1.3)),
      // Apple juice: 43 kcal, 0g fat, 10.5g carbs, 0g protein per 100ml
      // 250ml: 108 kcal, 0g fat, 26.3g carbs, 0g protein
      Liquid('Apple Juice', 250, LiquidMacros(calories: 108, fat: 0, carbs: 26.3, protein: 0)),
      Liquid('Tomato Juice', 100, LiquidMacros(calories: 19, fat: 0, carbs: 3.5, protein: 0.8)),
    ],
  ),
  // Monster Ultra (Zero)
  LiquidCategory(
    name: 'Monster Ultra (Zero Sugar)',
    icon: 'M',
    items: [
      Liquid('Ultra White', 500),
      Liquid('Ultra Paradise', 500),
      Liquid('Lando Norris', 500),
      Liquid('Ultra Watermelon', 500),
      Liquid('Ultra Black', 500),
      Liquid('Ultra Rosá', 500),
      Liquid('Ultra Gold', 500),
      Liquid('Ultra Fiesta Mango', 500),
      Liquid('Ultra Violet', 500),
      Liquid('Ultra Peachy Keen', 500),
    ],
  ),
  // Monster Original (with sugar)
  LiquidCategory(
    name: 'Monster Original',
    icon: 'M',
    items: [
      Liquid('Monster Energy (Green)', 500, LiquidMacros.cals(210)),
      Liquid('Monster Rio Punch', 500, LiquidMacros.cals(150)),
      Liquid('Monster Mango Loco', 500, LiquidMacros.cals(210)),
      Liquid('Monster Pipeline Punch', 500, LiquidMacros.cals(230)),
      Liquid('Monster Pacific Punch', 500, LiquidMacros.cals(230)),
    ],
  ),
  // Protein Heavy Drinks
  LiquidCategory(
    name: 'Protein Heavy Drinks',
    icon: '💪',
    items: [
      // Protein Shake: 400ml milk + banana + casein
      // ~550ml total: 410 kcal, 5g fat, 45g carbs, 48g protein
      Liquid('Protein Shake', 550, LiquidMacros(calories: 410, fat: 5, carbs: 45, protein: 48)),
      // Yt Kakao: 66 kcal, 0.9g fat, 8.7g carbs, 5.7g protein per 100ml
      // 330ml: 218 kcal, 3g fat, 28.7g carbs, 18.8g protein
      Liquid('Yt Kakao', 330, LiquidMacros(calories: 218, fat: 3, carbs: 28.7, protein: 18.8)),
      // Yt Banana Strawberry: 65 kcal, 0.8g fat, 8.7g carbs, 5.8g protein per 100ml
      // 330ml: 215 kcal, 2.6g fat, 28.7g carbs, 19.1g protein
      Liquid('Yt Banana Strawberry', 330, LiquidMacros(calories: 215, fat: 2.6, carbs: 28.7, protein: 19.1)),
    ],
  ),
];
