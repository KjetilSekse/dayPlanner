import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../models/menu.dart';
import '../models/recipe.dart';
import '../services/notification_service.dart';
import '../services/nutrition_service.dart';
import '../services/storage_service.dart';
import '../widgets/calendar_dialog.dart';
import '../widgets/meal_card.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_picker.dart';

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
  Map<String, String> _selectedMenus = {}; // dateStr -> menuId
  Map<String, String> _customTimes = {}; // dateStr-mealIdx -> time
  Map<String, String> _mealReplacements = {}; // dateStr-mealIdx or dayIdx-mealIdx -> recipeId
  Map<String, double> _mealPortions = {}; // dateStr-mealIdx -> portion multiplier
  Set<String> _completed = {};
  Set<String> _checkedIngredients = {};
  Map<String, Map<String, List<String>>> _dailyDrinks = {}; // dateStr -> drinkId -> list of timestamps
  bool _loaded = false;
  int _selectedMealCategory = 4; // 0=Breakfast, 1=Lunch, 2=Dinner, 3=Drinks, 4=Today
  late PageController _pageController;

  // Date-based navigation
  DateTime _currentDate = DateTime.now();
  late DateTime _displayedMonth; // First day of displayed month
  late int _daysInMonth;

  StorageService get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _initializeMonth(_currentDate);
    _load();
  }

  void _initializeMonth(DateTime date) {
    _displayedMonth = DateTime(date.year, date.month, 1);
    _daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final initialPage = date.day - 1; // 0-indexed
    _pageController = PageController(initialPage: initialPage);
  }

  DateTime _getDateForPage(int pageIndex) {
    return DateTime(_displayedMonth.year, _displayedMonth.month, pageIndex + 1);
  }

  String _formatDateTitle(DateTime date) {
    final dayName = dayNames[date.weekday - 1];
    final monthDay = DateFormat('MMM d').format(date);
    return '$dayName, $monthDay';
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
        _selectedMenus = _storage.loadSelectedMenusMap();
        _customTimes = _storage.loadCustomTimes();
        _mealReplacements = _storage.loadMealReplacements();
        _mealPortions = _storage.loadMealPortions();
        _notifOn = _storage.notificationsEnabled;
        _vibrateOn = _storage.vibrationEnabled;
        _completed = _storage.loadCompleted();
        _checkedIngredients = _storage.loadCheckedIngredients();
        _dailyDrinks = _storage.loadDailyDrinksMap();
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

  List<Meal> _getMealsForDate(DateTime date) {
    final menuId = _storage.getMenuForDate(date, _selectedMenus);
    final menu = _menus[menuId];
    if (menu == null) return [];

    return menu.meals.asMap().entries.map((e) {
      final customTime = _storage.getCustomTimeForDate(date, e.key, _customTimes);
      return customTime != null ? e.value.copyWith(time: customTime) : e.value;
    }).toList();
  }

  // Get NutritionService instance for current state
  NutritionService get _nutritionService => NutritionService(
    recipes: _recipes,
    categoryRecipes: _categoryRecipes,
    drinks: _drinks,
    mealReplacements: _mealReplacements,
    mealPortions: _mealPortions,
    dailyDrinks: _dailyDrinks,
  );

  // Calculate calories for a specific date
  int _calculateDayCalories(DateTime date) {
    return _nutritionService.getCaloriesForDate(date);
  }

  Future<void> _scheduleNotifications() async {
    if (!_notifOn) {
      await NotificationService.cancelAll();
      return;
    }

    // Only schedule today's meals
    final today = DateTime.now();
    final todayMeals = _getMealsForDate(today);
    await NotificationService.scheduleTodaysMeals(
      meals: todayMeals,
      vibrate: _vibrateOn,
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

  Future<void> _editMealTime(BuildContext context, DateTime date, int mealIdx, String currentTime) async {
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
      final dateStr = StorageService.dateToString(date);
      setState(() {
        _customTimes['$dateStr-$mealIdx'] = newTime;
      });
      await _storage.saveCustomTimes(_customTimes);
      if (_notifOn) _scheduleNotifications();
    }
  }

  Recipe? _getReplacementRecipe(DateTime date, int mealIdx) {
    final recipeId = _storage.getMealReplacementForDate(date, mealIdx, _mealReplacements);
    if (recipeId == null) return null;
    return _nutritionService.findRecipe(recipeId);
  }

  double _getPortionForMeal(DateTime date, int mealIdx) {
    return _storage.getPortionForDate(date, mealIdx, _mealPortions);
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

  void _showRecipePicker(BuildContext context, DateTime date, int mealIdx, String mealName) {
    final dateStr = StorageService.dateToString(date);
    final key = '$dateStr-$mealIdx';
    // Determine which category this meal belongs to (0=breakfast, 1=lunch, 2=dinner)
    final category = MealCategory.values[mealIdx.clamp(0, 2)];
    final availableRecipes = _getAllRecipesForCategory(category);

    // Get current recipe ID (check date-specific first, then weekday default)
    final currentRecipeId = _storage.getMealReplacementForDate(date, mealIdx, _mealReplacements);

    RecipePicker.show(
      context: context,
      mealName: mealName,
      recipes: availableRecipes,
      currentRecipeId: currentRecipeId,
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

  void _showPortionPicker(BuildContext context, DateTime date, int mealIdx) {
    final currentPortion = _getPortionForMeal(date, mealIdx);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Portion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${currentPortion}x'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((portion) {
                return ChoiceChip(
                  label: Text('${portion}x'),
                  selected: currentPortion == portion,
                  onSelected: (_) async {
                    setState(() {
                      final dateStr = StorageService.dateToString(date);
                      if (portion == 1.0) {
                        _mealPortions.remove('$dateStr-$mealIdx');
                      } else {
                        _mealPortions['$dateStr-$mealIdx'] = portion;
                      }
                    });
                    await _storage.saveMealPortions(_mealPortions);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
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

  void _showCalendarPicker() {
    showDialog(
      context: context,
      builder: (context) => CalendarDialog(
        initialDate: _currentDate,
        displayedMonth: _displayedMonth,
        calorieCalculator: _calculateDayCalories,
        onDateSelected: (date) {
          Navigator.pop(context);
          _jumpToDate(date);
        },
        onMonthChanged: (month) {
          // This will be handled inside the dialog
        },
      ),
    );
  }

  void _jumpToDate(DateTime date) {
    if (date.year == _displayedMonth.year && date.month == _displayedMonth.month) {
      // Same month, just jump to page
      _pageController.animateToPage(
        date.day - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentDate = date;
      });
    } else {
      // Different month, reinitialize
      _pageController.dispose();
      setState(() {
        _displayedMonth = DateTime(date.year, date.month, 1);
        _daysInMonth = DateTime(date.year, date.month + 1, 0).day;
        _currentDate = date;
        _pageController = PageController(initialPage: date.day - 1);
      });
    }
  }

  Widget _buildDayPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _daysInMonth,
      onPageChanged: (index) {
        setState(() {
          _currentDate = _getDateForPage(index);
        });
      },
      itemBuilder: (context, pageIndex) {
        final date = _getDateForPage(pageIndex);

        return Scaffold(
          appBar: AppBar(
            title: Text(_formatDateTitle(date)),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _showCalendarPicker,
                tooltip: 'Calendar',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
          body: _buildTodaysMeals(date),
          bottomNavigationBar: _buildBottomNav(),
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

  Widget _buildTodaysMeals(DateTime date) {
    final meals = _getMealsForDate(date);
    final dateStr = StorageService.dateToString(date);
    final dayDrinks = _dailyDrinks[dateStr] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily calories summary
        _buildDailySummary(date),
        const SizedBox(height: 8),
        // Regular meals
        ...meals.asMap().entries.map((entry) {
          final mealIdx = entry.key;
          final meal = entry.value;
          final mealId = '$dateStr-$mealIdx';
          final replacementRecipe = _getReplacementRecipe(date, mealIdx);
          final portion = _getPortionForMeal(date, mealIdx);

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
                    onTimeEdit: () => _editMealTime(context, date, mealIdx, meal.time),
                    onReplace: () => _showRecipePicker(context, date, mealIdx, meal.name),
                    portion: portion,
                    onPortionTap: () => _showPortionPicker(context, date, mealIdx),
                  )
                else
                  MealCard(
                    meal: meal,
                    mealId: mealId,
                    completed: _completed.contains(mealId),
                    checkedIngredients: _checkedIngredients,
                    onCompletedChanged: (v) => _toggleCompleted(mealId, v),
                    onIngredientChanged: _toggleIngredient,
                    onTimeEdit: () => _editMealTime(context, date, mealIdx, meal.time),
                    onReplace: () => _showRecipePicker(context, date, mealIdx, meal.name),
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
        _buildDrinksSection(date, dayDrinks),
      ],
    );
  }

  Widget _buildDailySummary(DateTime date) {
    final macros = _nutritionService.getMacrosForDate(date);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMacroItem('Calories', '${macros.calories}', 'kcal'),
            _buildMacroItem('Protein', '${macros.protein}', 'g'),
            _buildMacroItem('Carbs', '${macros.carbs}', 'g'),
            _buildMacroItem('Fat', '${macros.fat}', 'g'),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          '$label ($unit)',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDrinksSection(DateTime date, Map<String, List<String>> dayDrinks) {
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
              onPressed: () => _showDrinkPicker(context, date),
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
                      onPressed: () => _removeDrink(date, drinkId),
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
                      onPressed: () => _addDrink(date, drinkId),
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
                      onPressed: () => _removeDrink(date, drinkId, timestampIndex: index),
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
    final today = DateTime.now();

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
                onReplace: () => _selectRecipeForMeal(today, _selectedMealCategory, entry.key),
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
    final today = DateTime.now();
    final todayStr = StorageService.dateToString(today);
    final todayDrinks = _dailyDrinks[todayStr] ?? {};
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

  void _selectRecipeForMeal(DateTime date, int mealIdx, String recipeId) async {
    final dateStr = StorageService.dateToString(date);
    final key = '$dateStr-$mealIdx';
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

  Future<void> _addDrink(DateTime date, String drinkId) async {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = StorageService.dateToString(date);

    setState(() {
      _dailyDrinks[dateStr] ??= {};
      _dailyDrinks[dateStr]![drinkId] ??= [];
      _dailyDrinks[dateStr]![drinkId]!.add(timestamp);
    });
    await _storage.saveDailyDrinksMap(_dailyDrinks);
  }

  Future<void> _removeDrink(DateTime date, String drinkId, {int? timestampIndex}) async {
    final dateStr = StorageService.dateToString(date);
    setState(() {
      if (_dailyDrinks[dateStr] != null && _dailyDrinks[dateStr]![drinkId] != null) {
        if (timestampIndex != null && timestampIndex < _dailyDrinks[dateStr]![drinkId]!.length) {
          // Remove specific timestamp
          _dailyDrinks[dateStr]![drinkId]!.removeAt(timestampIndex);
        } else {
          // Remove last entry if no specific index
          _dailyDrinks[dateStr]![drinkId]!.removeLast();
        }

        // Clean up empty entries
        if (_dailyDrinks[dateStr]![drinkId]!.isEmpty) {
          _dailyDrinks[dateStr]!.remove(drinkId);
          if (_dailyDrinks[dateStr]!.isEmpty) {
            _dailyDrinks.remove(dateStr);
          }
        }
      }
    });
    await _storage.saveDailyDrinksMap(_dailyDrinks);
  }

  void _showDrinkPicker(BuildContext context, DateTime date) {
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
                  _addDrink(date, entry.key);
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
