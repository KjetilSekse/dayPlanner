import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/bread_meal.dart';
import 'bread_meal_builder.dart';

class RecipePicker extends StatelessWidget {
  final String mealName;
  final Map<String, Recipe> recipes;
  final String? currentRecipeId;
  final void Function(String? recipeId) onRecipeSelected;
  final bool showBreadMealOption;

  const RecipePicker({
    super.key,
    required this.mealName,
    required this.recipes,
    required this.currentRecipeId,
    required this.onRecipeSelected,
    this.showBreadMealOption = true,
  });

  static void show({
    required BuildContext context,
    required String mealName,
    required Map<String, Recipe> recipes,
    required String? currentRecipeId,
    required void Function(String? recipeId) onRecipeSelected,
    bool showBreadMealOption = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => RecipePicker(
          mealName: mealName,
          recipes: recipes,
          currentRecipeId: currentRecipeId,
          onRecipeSelected: onRecipeSelected,
          showBreadMealOption: showBreadMealOption,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if current selection is a bread meal
    BreadMeal? currentBreadMeal;
    if (currentRecipeId != null && BreadMeal.isBreadMealId(currentRecipeId!)) {
      currentBreadMeal = BreadMeal.fromEncodedId(currentRecipeId!);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Replace: $mealName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (currentRecipeId != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onRecipeSelected(null);
                  },
                  child: const Text('Reset to Default'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              // Bread Meal option
              if (showBreadMealOption) ...[
                ListTile(
                  leading: Icon(
                    currentBreadMeal != null ? Icons.check_circle : Icons.bakery_dining,
                    color: currentBreadMeal != null ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Bread with Topping'),
                  subtitle: Text(
                    currentBreadMeal != null
                        ? currentBreadMeal.generateName()
                        : 'Build a custom bread meal',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    BreadMealBuilder.show(
                      context: context,
                      initialMeal: currentBreadMeal,
                      onSave: (meal) {
                        onRecipeSelected(meal.toEncodedId());
                      },
                    );
                  },
                ),
                const Divider(),
              ],
              // Regular recipes
              ...recipes.entries.map((entry) {
                final recipe = entry.value;
                final isSelected = entry.key == currentRecipeId;

                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.restaurant,
                    color: isSelected ? Colors.green : null,
                  ),
                  title: Text(recipe.name),
                  subtitle: Text(
                    '${recipe.total.cals} | P: ${recipe.total.protein}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: _MacroChip(recipe: recipe),
                  onTap: () {
                    Navigator.pop(context);
                    onRecipeSelected(entry.key);
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final Recipe recipe;

  const _MacroChip({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        recipe.total.cals,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
