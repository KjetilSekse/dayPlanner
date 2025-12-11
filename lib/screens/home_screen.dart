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
  Map<int, String> _selectedMenus = {};
  Map<String, String> _customTimes = {};
  Map<String, String> _mealReplacements = {}; // dayIdx-mealIdx -> recipeId
  Set<String> _completed = {};
  Set<String> _checkedIngredients = {};
  bool _loaded = false;

  StorageService get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final menus = await _storage.loadMenus();
    final recipes = await _storage.loadRecipes();

    setState(() {
      _menus = menus;
      _recipes = recipes;
      _selectedMenus = _storage.loadSelectedMenus();
      _customTimes = _storage.loadCustomTimes();
      _mealReplacements = _storage.loadMealReplacements();
      _notifOn = _storage.notificationsEnabled;
      _vibrateOn = _storage.vibrationEnabled;
      _completed = _storage.loadCompleted();
      _checkedIngredients = _storage.loadCheckedIngredients();
      _loaded = true;
    });

    if (_notifOn) _scheduleNotifications();
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
    return _recipes[recipeId];
  }

  void _showRecipePicker(BuildContext context, int dayIdx, int mealIdx, String mealName) {
    final key = '$dayIdx-$mealIdx';
    RecipePicker.show(
      context: context,
      mealName: mealName,
      recipes: _recipes,
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PageView.builder(
      controller: PageController(initialPage: DateTime.now().weekday - 1),
      itemCount: 7,
      itemBuilder: (_, dayIdx) {
        final meals = _getMealsForDay(dayIdx);
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
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: meals.length,
            itemBuilder: (_, i) {
              final meal = meals[i];
              final mealId = '$dayIdx-$i';
              final replacementRecipe = _getReplacementRecipe(dayIdx, i);

              if (replacementRecipe != null) {
                return RecipeCard(
                  recipe: replacementRecipe,
                  mealId: mealId,
                  time: meal.time,
                  completed: _completed.contains(mealId),
                  checkedIngredients: _checkedIngredients,
                  onCompletedChanged: (v) => _toggleCompleted(mealId, v),
                  onIngredientChanged: _toggleIngredient,
                  onTimeEdit: () => _editMealTime(context, dayIdx, i, meal.time),
                  onReplace: () => _showRecipePicker(context, dayIdx, i, meal.name),
                );
              }

              return MealCard(
                meal: meal,
                mealId: mealId,
                completed: _completed.contains(mealId),
                checkedIngredients: _checkedIngredients,
                onCompletedChanged: (v) => _toggleCompleted(mealId, v),
                onIngredientChanged: _toggleIngredient,
                onTimeEdit: () => _editMealTime(context, dayIdx, i, meal.time),
                onReplace: () => _showRecipePicker(context, dayIdx, i, meal.name),
              );
            },
          ),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              onPressed: () => _showMenuPicker(ctx, dayIdx),
              icon: const Icon(Icons.restaurant_menu),
              label: Text(currentMenuName),
            ),
          ),
        );
      },
    );
  }
}
