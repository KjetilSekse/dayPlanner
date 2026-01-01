import 'package:flutter/material.dart';
import '../config/bread_toppings.dart';
import '../models/bread_meal.dart';

/// Dialog for building a custom bread meal
class BreadMealBuilder extends StatefulWidget {
  final BreadMeal? initialMeal;
  final void Function(BreadMeal meal) onSave;

  const BreadMealBuilder({
    super.key,
    this.initialMeal,
    required this.onSave,
  });

  /// Show the bread meal builder dialog
  static Future<void> show({
    required BuildContext context,
    BreadMeal? initialMeal,
    required void Function(BreadMeal meal) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BreadMealBuilder(
        initialMeal: initialMeal,
        onSave: onSave,
      ),
    );
  }

  @override
  State<BreadMealBuilder> createState() => _BreadMealBuilderState();
}

class _BreadMealBuilderState extends State<BreadMealBuilder> {
  String? _selectedBreadId;
  int _breadCount = 1;
  final List<_ToppingEntry> _toppings = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMeal != null) {
      _selectedBreadId = widget.initialMeal!.breadId;
      _breadCount = widget.initialMeal!.breadCount;
      for (final t in widget.initialMeal!.toppings) {
        _toppings.add(_ToppingEntry(
          toppingId: t.toppingId,
          controller: TextEditingController(text: t.grams.toStringAsFixed(0)),
        ));
      }
    } else if (breads.isNotEmpty) {
      _selectedBreadId = breads.first.id;
    }
  }

  @override
  void dispose() {
    for (final t in _toppings) {
      t.controller.dispose();
    }
    super.dispose();
  }

  BreadMeal _buildMeal() {
    return BreadMeal(
      breadId: _selectedBreadId!,
      breadCount: _breadCount,
      toppings: _toppings.map((t) {
        final grams = double.tryParse(t.controller.text) ?? 0;
        return SelectedTopping(toppingId: t.toppingId, grams: grams);
      }).toList(),
    );
  }

  void _addTopping() {
    if (toppings.isEmpty) return;

    // Find a topping not yet added, or use the first one
    String toppingId = toppings.first.id;
    final usedIds = _toppings.map((t) => t.toppingId).toSet();
    for (final topping in toppings) {
      if (!usedIds.contains(topping.id)) {
        toppingId = topping.id;
        break;
      }
    }

    final topping = getToppingById(toppingId);
    setState(() {
      _toppings.add(_ToppingEntry(
        toppingId: toppingId,
        controller: TextEditingController(
          text: topping?.defaultGrams.toStringAsFixed(0) ?? '15',
        ),
      ));
    });
  }

  void _removeTopping(int index) {
    setState(() {
      _toppings[index].controller.dispose();
      _toppings.removeAt(index);
    });
  }

  void _showToppingPicker(int toppingIndex) {
    showDialog(
      context: context,
      builder: (context) => _ToppingPickerDialog(
        currentToppingId: _toppings[toppingIndex].toppingId,
        onSelected: (toppingId) {
          final newTopping = getToppingById(toppingId);
          setState(() {
            _toppings[toppingIndex].toppingId = toppingId;
            _toppings[toppingIndex].controller.text =
                newTopping?.defaultGrams.toStringAsFixed(0) ?? '15';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = _selectedBreadId != null ? _buildMeal() : null;
    final macros = meal?.calculateTotalMacros();
    final weight = meal?.calculateTotalWeight() ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  'Build Bread Meal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Bread selection
                Text(
                  'Bread',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBreadId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: breads.map((bread) {
                    return DropdownMenuItem(
                      value: bread.id,
                      child: Text('${bread.name} (${bread.gramsPerUnit.toStringAsFixed(0)}g)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBreadId = value);
                  },
                ),
                const SizedBox(height: 12),
                // Bread count
                Row(
                  children: [
                    const Text('Count:'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _breadCount > 1
                          ? () => setState(() => _breadCount--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_breadCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _breadCount++),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Toppings section
                Row(
                  children: [
                    Text(
                      'Toppings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      onPressed: toppings.isNotEmpty ? _addTopping : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_toppings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No toppings added yet',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ..._toppings.asMap().entries.map((entry) {
                    final index = entry.key;
                    final toppingEntry = entry.value;
                    final topping = getToppingById(toppingEntry.toppingId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showToppingPicker(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              topping?.name ?? 'Select topping',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeTopping(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: toppingEntry.controller,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      suffixText: 'g',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (topping != null) ...[
                                  Text(
                                    'Default: ${topping.defaultGrams.toStringAsFixed(0)}g',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      toppingEntry.controller.text =
                                          topping.defaultGrams.toStringAsFixed(0);
                                      setState(() {});
                                    },
                                    child: const Text('Reset'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                // Summary
                if (macros != null) ...[
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            meal!.generateName(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${macros.calories} kcal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${macros.protein.toStringAsFixed(1)}g protein  |  ${macros.carbs.toStringAsFixed(1)}g carbs  |  ${macros.fat.toStringAsFixed(1)}g fat',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total weight: ${weight.toStringAsFixed(0)}g',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Save button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedBreadId != null
                    ? () {
                        final meal = _buildMeal();
                        widget.onSave(meal);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Bread Meal'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToppingEntry {
  String toppingId;
  final TextEditingController controller;

  _ToppingEntry({
    required this.toppingId,
    required this.controller,
  });
}

/// Dialog for picking a topping with collapsible categories
class _ToppingPickerDialog extends StatefulWidget {
  final String currentToppingId;
  final void Function(String toppingId) onSelected;

  const _ToppingPickerDialog({
    required this.currentToppingId,
    required this.onSelected,
  });

  @override
  State<_ToppingPickerDialog> createState() => _ToppingPickerDialogState();
}

class _ToppingPickerDialogState extends State<_ToppingPickerDialog> {
  final Set<String> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Topping'),
      contentPadding: const EdgeInsets.only(top: 16),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: toppingCategories.length,
          itemBuilder: (context, index) {
            final category = toppingCategories[index];
            final isExpanded = _expandedCategories.contains(category.name);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category header
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(category.name);
                      } else {
                        _expandedCategories.add(category.name);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        Text(category.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '${category.items.length}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                // Expanded items
                if (isExpanded)
                  ...category.items.map((topping) {
                    final isSelected = topping.id == widget.currentToppingId;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                      contentPadding: const EdgeInsets.only(left: 48, right: 16),
                      title: Text(topping.name),
                      subtitle: Text(
                        '${topping.defaultGrams.toStringAsFixed(0)}g default',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        widget.onSelected(topping.id);
                        Navigator.pop(context);
                      },
                    );
                  }),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
