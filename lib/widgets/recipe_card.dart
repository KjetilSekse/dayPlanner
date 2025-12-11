import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String mealId;
  final String time;
  final bool completed;
  final Set<String> checkedIngredients;
  final ValueChanged<bool?> onCompletedChanged;
  final void Function(String ingredientId, bool? value) onIngredientChanged;
  final VoidCallback onTimeEdit;
  final VoidCallback onReplace;
  final String replaceButtonText;
  final bool showReplaceButtonOutside;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.mealId,
    required this.time,
    required this.completed,
    required this.checkedIngredients,
    required this.onCompletedChanged,
    required this.onIngredientChanged,
    required this.onTimeEdit,
    required this.onReplace,
    this.replaceButtonText = 'Replace',
    this.showReplaceButtonOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: completed,
            onChanged: onCompletedChanged,
          ),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onTimeEdit,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            if (showReplaceButtonOutside)
              TextButton(
                onPressed: onReplace,
                child: Text(replaceButtonText),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Replace button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReplace,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(replaceButtonText),
                  ),
                ),
                // Ingredients section
                _IngredientsSection(
                  recipe: recipe,
                  mealId: mealId,
                  checkedIngredients: checkedIngredients,
                  onIngredientChanged: onIngredientChanged,
                ),
                const SizedBox(height: 16),
                // Instructions section
                _InstructionsSection(recipe: recipe),
                const SizedBox(height: 16),
                // Macros section
                _MacrosSection(recipe: recipe),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacrosSection extends StatelessWidget {
  final Recipe recipe;

  const _MacrosSection({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Macros',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: [
          _buildMacroTable(context),
        ],
      ),
    );
  }

  Widget _buildMacroTable(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        _buildHeaderRow(),
        _buildDataRow('Calories', recipe.per100g.cals, recipe.total.cals),
        _buildDataRow('Carbs', recipe.per100g.carbs, recipe.total.carbs),
        _buildDataRow('Fat', recipe.per100g.fat, recipe.total.fat),
        _buildDataRow('Protein', recipe.per100g.protein, recipe.total.protein),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Per 100g', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  TableRow _buildDataRow(String label, String per100g, String total) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(per100g),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(total),
        ),
      ],
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  final Recipe recipe;
  final String mealId;
  final Set<String> checkedIngredients;
  final void Function(String ingredientId, bool? value) onIngredientChanged;

  const _IngredientsSection({
    required this.recipe,
    required this.mealId,
    required this.checkedIngredients,
    required this.onIngredientChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Ingredients',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: recipe.ingredients.asMap().entries.map((entry) {
          final idx = entry.key;
          final ingredient = entry.value;
          final ingredientId = '$mealId-$idx';
          final isChecked = checkedIngredients.contains(ingredientId);

          return InkWell(
            onTap: () => onIngredientChanged(ingredientId, !isChecked),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    onChanged: (v) => onIngredientChanged(ingredientId, v),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      ingredient,
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked ? Colors.grey : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  final Recipe recipe;

  const _InstructionsSection({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Instructions',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: recipe.instructions.asMap().entries.map((entry) {
          final idx = entry.key;
          final instruction = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(instruction)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
