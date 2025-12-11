import 'package:flutter/material.dart';
import '../models/meal.dart';

class MealCard extends StatelessWidget {
  final Meal meal;
  final String mealId;
  final bool completed;
  final Set<String> checkedIngredients;
  final ValueChanged<bool?> onCompletedChanged;
  final void Function(String ingredientId, bool? value) onIngredientChanged;
  final VoidCallback onTimeEdit;
  final VoidCallback onReplace;

  const MealCard({
    super.key,
    required this.meal,
    required this.mealId,
    required this.completed,
    required this.checkedIngredients,
    required this.onCompletedChanged,
    required this.onIngredientChanged,
    required this.onTimeEdit,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final ingredients = meal.ingredientList;

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
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: GestureDetector(
          onTap: onTimeEdit,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(meal.time, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18),
              ],
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReplace,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Replace'),
                  ),
                ),
                ...ingredients.asMap().entries.map((entry) {
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
              }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
