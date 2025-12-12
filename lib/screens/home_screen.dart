import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../models/menu.dart';
import '../models/recipe.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/meal_card.dart';
import '../widgets/menu_picker.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_picker.dart';
import '../widgets/time_picker_sheet.dart';

const List<String> dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

class HomeScreen extends StatefulWidget {
  final StorageService storage;

  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notifOn = true;
  bool _vibrateOn = true;
  Map<String, Menu> _menus = {};
  Map<String, Recipe> _recipes = {};
  Map<MealCategory, Map<String, Recipe>> _categoryRecipes = {};
  Map<String, Recipe> _drinks = {};
  Map<int, String> _selectedMenus = {};
  Map<String, String> _customTimes = {};
  Map<String, String> _mealReplacements = {}; // dayIdx-mealIdx -> recipeId
  Set<String> _completed = {};
  Set<String> _checkedIngredients = {};
  Map<int, Map<String, List<String>>> _dailyDrinks = {}; // dayIdx -> drinkId -> list of timestamps
  bool _loaded = false;
  int _selectedMealCategory = 4; // 0=Breakfast, 1=Lunch, 2=Dinner, 3=Drinks, 4=Today
  late PageController _pageController;
  int _currentDayIdx = DateTime.now().weekday - 1;

  StorageService get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentDayIdx);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final menus = await _storage.loadMenus();
      final recipes = await _storage.loadRecipes();
      final categoryRecipes = await _storage.loadAllCategoryRecipes();
      final drinks = await _storage.loadDrinks();

      print('Drinks loaded in home screen: ${drinks.length}');
      print('Drink keys: ${drinks.keys.toList()}');

      setState(() {
        _menus = menus;
        _recipes = recipes;
        _categoryRecipes = categoryRecipes;
        _drinks = drinks;
        _selectedMenus = _storage.loadSelectedMenus();
        _customTimes = _storage.loadCustomTimes();
        _mealReplacements = _storage.loadMealReplacements();
        _notifOn = _storage.notificationsEnabled;
        _vibrateOn = _storage.vibrationEnabled;
        _completed = _storage.loadCompleted();
        _checkedIngredients = _storage.loadCheckedIngredients();
        _dailyDrinks = _storage.loadDailyDrinks();
        _loaded = true;
      });

      if (_notifOn) _scheduleNotifications();
    } catch (e, stackTrace) {
      print('Error loading data: $e');
      print('Stack trace: $stackTrace');
      // Still mark as loaded to prevent infinite loading, but with empty data
      setState(() {
        _loaded = true;
      });
    }
  }

  List<Meal> _getMealsForDay(int dayIdx) {
    final menuId = _selectedMenus[dayIdx] ?? StorageService.menuIds.first;
    final menu = _menus[menuId];
    if (menu == null) return [];

    return menu.meals.asMap().entries.map((e) {
      final customTime = _customTimes['$dayIdx-${e.key}'];
      return customTime != null ? e.value.copyWith(time: customTime) : e.value;
    }).toList();
  }

  Future<void> _scheduleNotifications() async {
    if (!_notifOn) {
      await NotificationService.cancelAll();
      return;
    }

    // Only schedule today's meals
    final todayIdx = DateTime.now().weekday - 1; // 0 = Monday
    final todayMeals = _getMealsForDay(todayIdx);
    await NotificationService.scheduleTodaysMeals(
      meals: todayMeals,
      vibrate: _vibrateOn,
    );
  }

  void _showMenuPicker(BuildContext context, int dayIdx) {
    MenuPicker.show(
      context: context,
      dayName: dayNames[dayIdx],
      menus: _menus,
      currentMenuId: _selectedMenus[dayIdx] ?? StorageService.menuIds.first,
      onMenuSelected: (menuId) => _showTimePicker(context, dayIdx, menuId),
    );
  }

  void _showTimePicker(BuildContext context, int dayIdx, String menuId) {
    final menu = _menus[menuId];
    if (menu == null) return;

    // Get meals with any existing custom times
    final meals = menu.meals.asMap().entries.map((e) {
      final customTime = _customTimes['$dayIdx-${e.key}'];
      return customTime != null ? e.value.copyWith(time: customTime) : e.value;
    }).toList();

    TimePickerSheet.show(
      context: context,
      dayName: dayNames[dayIdx],
      meals: meals,
      onSave: (savedMeals, useDefaults) async {
        setState(() {
          _selectedMenus[dayIdx] = menuId;

          if (useDefaults) {
            // Clear custom times for this day
            for (int i = 0; i < savedMeals.length; i++) {
              _customTimes.remove('$dayIdx-$i');
            }
          } else {
            // Save custom times
            for (int i = 0; i < savedMeals.length; i++) {
              _customTimes['$dayIdx-$i'] = savedMeals[i].time;
            }
          }
        });

        await _storage.saveSelectedMenu(dayIdx, menuId);
        await _storage.saveCustomTimes(_customTimes);
        if (_notifOn) _scheduleNotifications();
      },
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Notifications'),
                value: _notifOn,
                onChanged: (v) async {
                  setDialogState(() => _notifOn = v);
                  setState(() => _notifOn = v);
                  await _storage.setNotificationsEnabled(v);
                  if (v) {
                    _scheduleNotifications();
                  } else {
                    NotificationService.cancelAll();
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                value: _vibrateOn,
                onChanged: (v) async {
                  setDialogState(() => _vibrateOn = v);
                  setState(() => _vibrateOn = v);
                  await _storage.setVibrationEnabled(v);
                  if (_notifOn) _scheduleNotifications();
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Test Notification'),
                subtitle: const Text('Shows immediately'),
                trailing: const Icon(Icons.notifications_active),
                onTap: () {
                  NotificationService.testNotification();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Test Scheduled (1 min)'),
                subtitle: const Text('Fires in 1 minute'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await NotificationService.testScheduledNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result), duration: const Duration(seconds: 5)),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Check Pending'),
                subtitle: const Text('Show scheduled notifications'),
                trailing: const Icon(Icons.list),
                onTap: () async {
                  final pending = await NotificationService.getPendingNotifications();
                  if (context.mounted) {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Pending: ${pending.length}'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: pending.isEmpty
                                ? [const Text('No pending notifications')]
                                : pending.map((n) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text('${n.id}: ${n.title}'),
                                  )).toList(),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCompleted(String id, bool? value) async {
    setState(() {
      if (value == true) {
        _completed.add(id);
      } else {
        _completed.remove(id);
      }
    });
    await _storage.saveCompleted(_completed);
  }

  Future<void> _toggleIngredient(String ingredientId, bool? value) async {
    setState(() {
      if (value == true) {
        _checkedIngredients.add(ingredientId);
      } else {
        _checkedIngredients.remove(ingredientId);
      }
    });
    await _storage.saveCheckedIngredients(_checkedIngredients);
  }

  Future<void> _editMealTime(BuildContext context, int dayIdx, int mealIdx, String currentTime) async {
    final parts = currentTime.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _customTimes['$dayIdx-$mealIdx'] = newTime;
      });
      await _storage.saveCustomTimes(_customTimes);
      if (_notifOn) _scheduleNotifications();
    }
  }

  Recipe? _getReplacementRecipe(int dayIdx, int mealIdx) {
    final key = '$dayIdx-$mealIdx';
    final recipeId = _mealReplacements[key];
    if (recipeId == null) return null;
    // Check in general recipes first, then in category recipes
    if (_recipes.containsKey(recipeId)) {
      return _recipes[recipeId];
    }
    // Search through category recipes
    for (final categoryMap in _categoryRecipes.values) {
      if (categoryMap.containsKey(recipeId)) {
        return categoryMap[recipeId];
      }
    }
    return null;
  }

  Map<String, Recipe> _getAllRecipesForCategory(MealCategory category) {
    final allRecipes = <String, Recipe>{};
    // Add category-specific recipes
    final categoryMap = _categoryRecipes[category];
    if (categoryMap != null) {
      allRecipes.addAll(categoryMap);
    }
    // Only add general recipes for dinner category
    if (category == MealCategory.dinner) {
      allRecipes.addAll(_recipes);
    }
    return allRecipes;
  }

  void _showRecipePicker(BuildContext context, int dayIdx, int mealIdx, String mealName) {
    final key = '$dayIdx-$mealIdx';
    // Determine which category this meal belongs to (0=breakfast, 1=lunch, 2=dinner)
    final category = MealCategory.values[mealIdx.clamp(0, 2)];
    final availableRecipes = _getAllRecipesForCategory(category);

    RecipePicker.show(
      context: context,
      mealName: mealName,
      recipes: availableRecipes,
      currentRecipeId: _mealReplacements[key],
      onRecipeSelected: (recipeId) async {
        setState(() {
          if (recipeId == null) {
            _mealReplacements.remove(key);
          } else {
            _mealReplacements[key] = recipeId;
          }
        });
        await _storage.saveMealReplacements(_mealReplacements);
      },
    );
  }

  MealCategory get _currentCategory =>
      _selectedMealCategory < 3 ? MealCategory.values[_selectedMealCategory] : MealCategory.breakfast;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show PageView for Today tab, simple scaffold for cookbook tabs
    if (_selectedMealCategory == 4) {
      return _buildDayPageView();
    }

    // Handle Drinks tab (index 3)
    if (_selectedMealCategory == 3) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Drinks'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettings(context),
            ),
          ],
        ),
        body: _buildDrinks(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentCategory.name.capitalize()} Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: _buildCookbook(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDayPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: 7,
      onPageChanged: (index) {
        setState(() {
          _currentDayIdx = index;
        });
      },
      itemBuilder: (context, dayIdx) {
        final currentMenuId = _selectedMenus[dayIdx] ?? StorageService.menuIds.first;
        final currentMenuName = _menus[currentMenuId]?.name ?? currentMenuId;

        return Scaffold(
          appBar: AppBar(
            title: Text(dayNames[dayIdx]),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
          body: _buildTodaysMeals(dayIdx),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showMenuPicker(context, dayIdx),
            icon: const Icon(Icons.restaurant_menu),
            label: Text(currentMenuName),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedMealCategory,
      onDestinationSelected: (index) {
        setState(() {
          _selectedMealCategory = index;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.free_breakfast_outlined),
          selectedIcon: Icon(Icons.free_breakfast),
          label: 'Breakfast',
        ),
        NavigationDestination(
          icon: Icon(Icons.lunch_dining_outlined),
          selectedIcon: Icon(Icons.lunch_dining),
          label: 'Lunch',
        ),
        NavigationDestination(
          icon: Icon(Icons.dinner_dining_outlined),
          selectedIcon: Icon(Icons.dinner_dining),
          label: 'Dinner',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_bar_outlined),
          selectedIcon: Icon(Icons.local_bar),
          label: 'Drinks',
        ),
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today),
          label: 'Today',
        ),
      ],
    );
  }

  String _getMealLabel(int mealIdx) {
    switch (mealIdx) {
      case 0:
        return 'Breakfast';
      case 1:
        return 'Lunch';
      case 2:
        return 'Dinner';
      default:
        return '';
    }
  }

  Widget _buildTodaysMeals(int dayIdx) {
    final meals = _getMealsForDay(dayIdx);
    final dayDrinks = _dailyDrinks[dayIdx] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Regular meals
        ...meals.asMap().entries.map((entry) {
          final mealIdx = entry.key;
          final meal = entry.value;
          final mealId = '$dayIdx-$mealIdx';
          final replacementRecipe = _getReplacementRecipe(dayIdx, mealIdx);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Stack(
              children: [
                if (replacementRecipe != null)
                  RecipeCard(
                    recipe: replacementRecipe,
                    mealId: mealId,
                    time: meal.time,
                    completed: _completed.contains(mealId),
                    checkedIngredients: _checkedIngredients,
                    onCompletedChanged: (v) => _toggleCompleted(mealId, v),
                    onIngredientChanged: _toggleIngredient,
                    onTimeEdit: () => _editMealTime(context, dayIdx, mealIdx, meal.time),
                    onReplace: () => _showRecipePicker(context, dayIdx, mealIdx, meal.name),
                  )
                else
                  MealCard(
                    meal: meal,
                    mealId: mealId,
                    completed: _completed.contains(mealId),
                    checkedIngredients: _checkedIngredients,
                    onCompletedChanged: (v) => _toggleCompleted(mealId, v),
                    onIngredientChanged: _toggleIngredient,
                    onTimeEdit: () => _editMealTime(context, dayIdx, mealIdx, meal.time),
                    onReplace: () => _showRecipePicker(context, dayIdx, mealIdx, meal.name),
                  ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: Text(
                    _getMealLabel(mealIdx),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        // Drinks section
        _buildDrinksSection(dayIdx, dayDrinks),
      ],
    );
  }

  Widget _buildDrinksSection(int dayIdx, Map<String, List<String>> dayDrinks) {
    // Calculate total calories and carbs for this day
    int totalCalories = 0;
    int totalCarbs = 0;

    for (final entry in dayDrinks.entries) {
      final drinkId = entry.key;
      final timestamps = entry.value;
      final drink = _drinks[drinkId];
      if (drink != null) {
        totalCalories += int.parse(drink.total.cals) * timestamps.length;
        totalCarbs += (double.parse(drink.total.carbs) * timestamps.length).round();
      }
    }

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.local_bar),
        title: Row(
          children: [
            const Text('Drinks'),
            if (dayDrinks.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '($totalCalories cal)',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dayDrinks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dayDrinks.values.fold(0, (sum, timestamps) => sum + timestamps.length)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showDrinkPicker(context, dayIdx),
              tooltip: 'Add drink',
            ),
          ],
        ),
        children: [
          if (dayDrinks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No drinks added yet. Tap + to add.'),
            )
          else ...[
            // Total summary row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '$totalCalories cal • ${totalCarbs}g carbs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Individual drinks
            ...dayDrinks.entries.map((entry) {
              final drinkId = entry.key;
              final timestamps = entry.value;
              final drink = _drinks[drinkId];

              if (drink == null) return const SizedBox.shrink();

              return ExpansionTile(
                leading: const Icon(Icons.local_bar),
                title: Text(drink.name),
                subtitle: Text('${drink.total.cals} cal • ${drink.total.carbs}g carbs'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeDrink(dayIdx, drinkId),
                      tooltip: 'Remove one',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'x${timestamps.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _addDrink(dayIdx, drinkId),
                      tooltip: 'Add one',
                    ),
                  ],
                ),
                children: timestamps.asMap().entries.map((timestampEntry) {
                  final index = timestampEntry.key;
                  final timestamp = timestampEntry.value;
                  return ListTile(
                    leading: const Icon(Icons.access_time, size: 20),
                    title: Text('Entry ${index + 1}'),
                    subtitle: Text('Time: $timestamp'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _removeDrink(dayIdx, drinkId, timestampIndex: index),
                      tooltip: 'Delete this entry',
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCookbook() {
    final categoryRecipes = _categoryRecipes[_currentCategory] ?? {};
    final todayIdx = DateTime.now().weekday - 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_currentCategory.name.capitalize()} Recipes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (categoryRecipes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recipes in this category yet'),
            ),
          )
        else
          ...categoryRecipes.entries.map((entry) {
            final recipe = entry.value;
            final recipeId = 'cookbook-${entry.key}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecipeCard(
                recipe: recipe,
                mealId: recipeId,
                time: _getDefaultTimeForCategory(_currentCategory),
                completed: _completed.contains(recipeId),
                checkedIngredients: _checkedIngredients,
                onCompletedChanged: (v) => _toggleCompleted(recipeId, v),
                onIngredientChanged: _toggleIngredient,
                onTimeEdit: () {},
                onReplace: () => _selectRecipeForMeal(todayIdx, _selectedMealCategory, entry.key),
                replaceButtonText: 'Set for today',
                showReplaceButtonOutside: true,
              ),
            );
          }),
      ],
    );
  }

  String _getDefaultTimeForCategory(MealCategory category) {
    switch (category) {
      case MealCategory.breakfast:
        return '08:00';
      case MealCategory.lunch:
        return '12:00';
      case MealCategory.dinner:
        return '18:00';
    }
  }

  Widget _buildDrinks() {
    print('Building drinks view. Drinks count: ${_drinks.length}');
    print('Drinks: ${_drinks.keys.toList()}');

    // Calculate today's total drink calories
    final todayIdx = DateTime.now().weekday - 1;
    final todayDrinks = _dailyDrinks[todayIdx] ?? {};
    int totalCalories = 0;
    int totalCarbs = 0;

    for (final entry in todayDrinks.entries) {
      final drinkId = entry.key;
      final timestamps = entry.value;
      final drink = _drinks[drinkId];
      if (drink != null) {
        totalCalories += int.parse(drink.total.cals) * timestamps.length;
        totalCarbs += (double.parse(drink.total.carbs) * timestamps.length).round();
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Today's drinks summary card
        if (todayDrinks.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Drinks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${todayDrinks.values.fold(0, (sum, timestamps) => sum + timestamps.length)} drink${todayDrinks.values.fold(0, (sum, timestamps) => sum + timestamps.length) == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalCalories cal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '$totalCarbs g carbs',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (todayDrinks.isNotEmpty) const SizedBox(height: 16),
        Text(
          'Available Drinks',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_drinks.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No drinks available yet'),
            ),
          )
        else
          ..._drinks.entries.map((entry) {
            final drink = entry.value;
            final drinkId = 'drink-${entry.key}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecipeCard(
                recipe: drink,
                mealId: drinkId,
                time: '20:00',
                completed: _completed.contains(drinkId),
                checkedIngredients: _checkedIngredients,
                onCompletedChanged: (v) => _toggleCompleted(drinkId, v),
                onIngredientChanged: _toggleIngredient,
                onTimeEdit: () {},
                onReplace: () {},
                showReplaceButtonOutside: false,
              ),
            );
          }),
      ],
    );
  }

  void _selectRecipeForMeal(int dayIdx, int mealIdx, String recipeId) async {
    final key = '$dayIdx-$mealIdx';
    setState(() {
      _mealReplacements[key] = recipeId;
    });
    await _storage.saveMealReplacements(_mealReplacements);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe set for today\'s ${_currentCategory.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addDrink(int dayIdx, String drinkId) async {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _dailyDrinks[dayIdx] ??= {};
      _dailyDrinks[dayIdx]![drinkId] ??= [];
      _dailyDrinks[dayIdx]![drinkId]!.add(timestamp);
    });
    await _storage.saveDailyDrinks(_dailyDrinks);
  }

  Future<void> _removeDrink(int dayIdx, String drinkId, {int? timestampIndex}) async {
    setState(() {
      if (_dailyDrinks[dayIdx] != null && _dailyDrinks[dayIdx]![drinkId] != null) {
        if (timestampIndex != null && timestampIndex < _dailyDrinks[dayIdx]![drinkId]!.length) {
          // Remove specific timestamp
          _dailyDrinks[dayIdx]![drinkId]!.removeAt(timestampIndex);
        } else {
          // Remove last entry if no specific index
          _dailyDrinks[dayIdx]![drinkId]!.removeLast();
        }

        // Clean up empty entries
        if (_dailyDrinks[dayIdx]![drinkId]!.isEmpty) {
          _dailyDrinks[dayIdx]!.remove(drinkId);
          if (_dailyDrinks[dayIdx]!.isEmpty) {
            _dailyDrinks.remove(dayIdx);
          }
        }
      }
    });
    await _storage.saveDailyDrinks(_dailyDrinks);
  }

  void _showDrinkPicker(BuildContext context, int dayIdx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Drink'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _drinks.entries.map((entry) {
              return ListTile(
                title: Text(entry.value.name),
                onTap: () {
                  _addDrink(dayIdx, entry.key);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
