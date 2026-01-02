import 'package:flutter/material.dart';
import '../config/ingredients.dart';
import '../models/meal_item.dart';
import '../models/recipe.dart';
import '../models/snack.dart';
import '../models/bread_meal.dart';
import '../services/storage_service.dart';
import 'bread_meal_builder.dart';

/// Tab categories for meal picker
enum MealPickerTab {
  breakfast,
  lunch,
  dinner,
  snacks,
  bread,
}

class RecipePicker extends StatefulWidget {
  final String mealName;
  final MealCategory defaultCategory; // Which tab to open by default
  final Map<MealCategory, Map<String, Recipe>> categoryRecipes;
  final Map<String, Snack> snacks;
  final String? currentRecipeId;
  final void Function(String? recipeId) onRecipeSelected;
  final void Function(String encodedItem)? onIngredientAdded; // For adding extra ingredients

  const RecipePicker({
    super.key,
    required this.mealName,
    required this.defaultCategory,
    required this.categoryRecipes,
    required this.snacks,
    required this.currentRecipeId,
    required this.onRecipeSelected,
    this.onIngredientAdded,
  });

  static void show({
    required BuildContext context,
    required String mealName,
    required MealCategory defaultCategory,
    required Map<MealCategory, Map<String, Recipe>> categoryRecipes,
    required Map<String, Snack> snacks,
    required String? currentRecipeId,
    required void Function(String? recipeId) onRecipeSelected,
    void Function(String encodedItem)? onIngredientAdded,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => RecipePicker(
          mealName: mealName,
          defaultCategory: defaultCategory,
          categoryRecipes: categoryRecipes,
          snacks: snacks,
          currentRecipeId: currentRecipeId,
          onRecipeSelected: onRecipeSelected,
          onIngredientAdded: onIngredientAdded,
        ),
      ),
    );
  }

  @override
  State<RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<RecipePicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Map MealCategory to tab index
  int _getInitialTabIndex() {
    switch (widget.defaultCategory) {
      case MealCategory.breakfast:
        return 0;
      case MealCategory.lunch:
        return 1;
      case MealCategory.dinner:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6, // Breakfast, Lunch, Dinner, Snacks, Bread, Ingredients
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if current selection is a bread meal
    BreadMeal? currentBreadMeal;
    if (widget.currentRecipeId != null && BreadMeal.isBreadMealId(widget.currentRecipeId!)) {
      currentBreadMeal = BreadMeal.fromEncodedId(widget.currentRecipeId!);
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select: ${widget.mealName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.currentRecipeId != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRecipeSelected(null);
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        // Tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Breakfast'),
            Tab(text: 'Lunch'),
            Tab(text: 'Dinner'),
            Tab(text: 'Snacks'),
            Tab(text: 'Bread'),
            Tab(text: 'Ingredients'),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecipeList(widget.categoryRecipes[MealCategory.breakfast] ?? {}),
              _buildRecipeList(widget.categoryRecipes[MealCategory.lunch] ?? {}),
              _buildRecipeList(widget.categoryRecipes[MealCategory.dinner] ?? {}),
              _buildSnackList(),
              _buildBreadTab(currentBreadMeal),
              _buildIngredientsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeList(Map<String, Recipe> recipes) {
    if (recipes.isEmpty) {
      return const Center(
        child: Text('No recipes available', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final entry = recipes.entries.elementAt(index);
        final recipe = entry.value;
        final isSelected = entry.key == widget.currentRecipeId;

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
          trailing: _MacroChip(text: recipe.total.cals),
          onTap: () {
            Navigator.pop(context);
            widget.onRecipeSelected(entry.key);
          },
        );
      },
    );
  }

  Widget _buildSnackList() {
    if (widget.snacks.isEmpty) {
      return const Center(
        child: Text('No snacks available', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: widget.snacks.length,
      itemBuilder: (context, index) {
        final entry = widget.snacks.entries.elementAt(index);
        final snack = entry.value;
        // Snacks use 'snack:id' format to distinguish from recipes
        final snackId = 'snack:${entry.key}';
        final isSelected = snackId == widget.currentRecipeId;

        return ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.cookie,
            color: isSelected ? Colors.green : Colors.orange,
          ),
          title: Text(snack.name),
          subtitle: Text(
            '${snack.perServing.cals} kcal | ${snack.servingGrams.toStringAsFixed(0)}g serving',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: _MacroChip(text: '${snack.perServing.cals} kcal'),
          onTap: () {
            Navigator.pop(context);
            widget.onRecipeSelected(snackId);
          },
        );
      },
    );
  }

  Widget _buildBreadTab(BreadMeal? currentBreadMeal) {
    final isSelected = currentBreadMeal != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.bakery_dining,
              color: isSelected ? Colors.green : Colors.orange,
              size: 32,
            ),
            title: const Text('Build Bread Meal'),
            subtitle: Text(
              isSelected
                  ? currentBreadMeal.generateName()
                  : 'Create a custom bread with toppings',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              BreadMealBuilder.show(
                context: context,
                initialMeal: currentBreadMeal,
                onSave: (meal) {
                  widget.onRecipeSelected(meal.toEncodedId());
                },
              );
            },
          ),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildBreadMealSummary(currentBreadMeal),
          ),
      ],
    );
  }

  Widget _buildBreadMealSummary(BreadMeal meal) {
    final macros = meal.calculateTotalMacros();
    final cals = macros?.calories ?? 0;
    final protein = macros?.protein ?? 0;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Selection',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              meal.generateName(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$cals kcal | ${protein.toStringAsFixed(1)}g protein',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsTab() {
    if (widget.onIngredientAdded == null) {
      return const Center(
        child: Text(
          'Ingredient adding not available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (ingredientCategories.isEmpty ||
        ingredientCategories.every((cat) => cat.items.isEmpty)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No ingredients configured yet.\nAdd ingredients to lib/config/ingredients.dart',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: ingredientCategories.length,
      itemBuilder: (context, index) {
        final category = ingredientCategories[index];
        if (category.items.isEmpty) return const SizedBox.shrink();

        return ExpansionTile(
          leading: Text(category.icon, style: const TextStyle(fontSize: 24)),
          title: Text(category.name),
          subtitle: Text(
            '${category.items.length} items',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          children: category.items.map((ingredient) {
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: Text(ingredient.name),
              subtitle: Text(
                '${ingredient.per100g.calories} kcal/100g | P: ${ingredient.per100g.protein.toStringAsFixed(1)}g',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              trailing: _MacroChip(text: '${ingredient.defaultGrams.toStringAsFixed(0)}g'),
              onTap: () => _showGramInputDialog(ingredient),
            );
          }).toList(),
        );
      },
    );
  }

  void _showGramInputDialog(Ingredient ingredient) {
    final controller = TextEditingController(
      text: ingredient.defaultGrams.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Add ${ingredient.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Macros per 100g: ${ingredient.per100g.calories} kcal',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final grams = double.tryParse(value.text) ?? 0;
                  final macros = ingredient.macrosForGrams(grams);
                  return Text(
                    '${macros.calories} kcal | F: ${macros.fat.toStringAsFixed(1)}g | C: ${macros.carbs.toStringAsFixed(1)}g | P: ${macros.protein.toStringAsFixed(1)}g',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final grams = double.tryParse(controller.text);
                if (grams != null && grams > 0) {
                  final mealItem = MealItem(
                    ingredientId: ingredient.id,
                    grams: grams,
                  );
                  Navigator.pop(dialogContext);
                  Navigator.pop(context); // Close the picker
                  widget.onIngredientAdded!(mealItem.toEncodedId());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String text;

  const _MacroChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
