import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

const List<String> menuFiles = ['healthy', 'quick', 'vegetarian'];
const List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));

  const channel = AndroidNotificationChannel(
    'meal_channel',
    'Meal Reminders',
    description: 'Daily meal notifications',
    importance: Importance.high,
    playSound: true,
  );
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MealApp());
}

class MealApp extends StatefulWidget {
  const MealApp({super.key});
  @override
  State<MealApp> createState() => _MealAppState();
}

class _MealAppState extends State<MealApp> {
  bool notifOn = true;
  bool vibrateOn = true;
  Map<String, dynamic> menus = {};
  Map<int, String> selectedMenus = {};
  Map<String, String> customTimes = {}; // key: "dayIdx-mealIdx", value: "HH:mm"
  Set<String> completed = {};
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedMenus = <String, dynamic>{};

    for (final file in menuFiles) {
      final jsonString = await DefaultAssetBundle.of(context).loadString('assets/menus/$file.json');
      final data = json.decode(jsonString);
      loadedMenus[file] = data;
    }

    final savedSelections = <int, String>{};
    for (int i = 0; i < 7; i++) {
      savedSelections[i] = prefs.getString('menu_$i') ?? menuFiles.first;
    }

    final savedTimes = <String, String>{};
    final timesJson = prefs.getString('customTimes');
    if (timesJson != null) {
      final decoded = json.decode(timesJson) as Map<String, dynamic>;
      decoded.forEach((k, v) => savedTimes[k] = v as String);
    }

    setState(() {
      menus = loadedMenus;
      selectedMenus = savedSelections;
      customTimes = savedTimes;
      notifOn = prefs.getBool('notif') ?? true;
      vibrateOn = prefs.getBool('vib') ?? true;
      completed = prefs.getStringList('done')?.toSet() ?? {};
      loaded = true;
    });

    if (notifOn) _scheduleAll();
  }

  String _getMealTime(int dayIdx, int mealIdx, String defaultTime) {
    return customTimes['$dayIdx-$mealIdx'] ?? defaultTime;
  }

  Map<String, dynamic> _getMealsForDay(int dayIdx) {
    final menuKey = selectedMenus[dayIdx] ?? menuFiles.first;
    final menu = menus[menuKey];
    if (menu == null) return {'day': dayNames[dayIdx], 'meals': []};

    final meals = (menu['meals'] as List).asMap().entries.map((e) {
      final meal = Map<String, dynamic>.from(e.value);
      meal['time'] = _getMealTime(dayIdx, e.key, meal['time']);
      return meal;
    }).toList();

    return {'day': dayNames[dayIdx], 'meals': meals};
  }

  Future<void> _scheduleAll() async {
    await notifications.cancelAll();
    if (!notifOn) return;

    int id = 0;
    final now = DateTime.now();

    for (int d = 0; d < 7; d++) {
      final day = _getMealsForDay(d);
      for (var m in day['meals']) {
        final t = m['time'].split(':');
        var when = DateTime(now.year, now.month, now.day + d, int.parse(t[0]), int.parse(t[1]));
        if (when.isBefore(now)) when = when.add(const Duration(days: 7));

        await notifications.zonedSchedule(
          id++,
          m['name'],
          'Time to eat: ${m['name']}',
          tz.TZDateTime.from(when, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'meal_channel',
              'Meal Reminders',
              channelDescription: 'Daily meal notifications',
              importance: Importance.high,
              playSound: true,
              enableVibration: vibrateOn,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  void _showMenuPicker(BuildContext context, int dayIdx) {
    final currentMenu = selectedMenus[dayIdx] ?? menuFiles.first;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Menu for ${dayNames[dayIdx]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...menuFiles.map((file) {
            final menuName = menus[file]?['name'] ?? file;
            final isSelected = file == currentMenu;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.green : null,
              ),
              title: Text(menuName),
              onTap: () {
                Navigator.pop(ctx);
                _showTimePicker(context, dayIdx, file);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showTimePicker(BuildContext context, int dayIdx, String menuKey) {
    final menu = menus[menuKey];
    if (menu == null) return;

    final meals = List<Map<String, dynamic>>.from(
      (menu['meals'] as List).map((m) => Map<String, dynamic>.from(m)),
    );

    // Initialize with custom times if they exist, otherwise use defaults
    for (int i = 0; i < meals.length; i++) {
      meals[i]['time'] = customTimes['$dayIdx-$i'] ?? meals[i]['time'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set Meal Times for ${dayNames[dayIdx]}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...meals.asMap().entries.map((e) {
                final i = e.key;
                final meal = e.value;
                return ListTile(
                  title: Text(meal['name']),
                  trailing: TextButton(
                    onPressed: () async {
                      final parts = meal['time'].split(':');
                      final initial = TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      );
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initial,
                      );
                      if (picked != null) {
                        setModalState(() {
                          meals[i]['time'] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Text(meal['time'], style: const TextStyle(fontSize: 16)),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        // Use default times - clear custom times for this day
                        final prefs = await SharedPreferences.getInstance();
                        setState(() {
                          for (int i = 0; i < meals.length; i++) {
                            customTimes.remove('$dayIdx-$i');
                          }
                          selectedMenus[dayIdx] = menuKey;
                        });
                        await prefs.setString('customTimes', json.encode(customTimes));
                        await prefs.setString('menu_$dayIdx', menuKey);
                        if (notifOn) _scheduleAll();
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Use Defaults'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        // Save custom times
                        final prefs = await SharedPreferences.getInstance();
                        setState(() {
                          for (int i = 0; i < meals.length; i++) {
                            customTimes['$dayIdx-$i'] = meals[i]['time'];
                          }
                          selectedMenus[dayIdx] = menuKey;
                        });
                        await prefs.setString('customTimes', json.encode(customTimes));
                        await prefs.setString('menu_$dayIdx', menuKey);
                        if (notifOn) _scheduleAll();
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Times'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: PageView.builder(
        controller: PageController(initialPage: DateTime.now().weekday - 1),
        itemCount: 7,
        itemBuilder: (_, dayIdx) {
          final day = _getMealsForDay(dayIdx);
          final currentMenuKey = selectedMenus[dayIdx] ?? menuFiles.first;
          final currentMenuName = menus[currentMenuKey]?['name'] ?? currentMenuKey;

          return Scaffold(
            appBar: AppBar(
              title: Text(day['day']),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Settings'),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        SwitchListTile(
                          title: const Text('Notifications'),
                          value: notifOn,
                          onChanged: (v) async {
                            final p = await SharedPreferences.getInstance();
                            setState(() => notifOn = v);
                            await p.setBool('notif', v);
                            v ? _scheduleAll() : notifications.cancelAll();
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Vibration'),
                          value: vibrateOn,
                          onChanged: (v) async {
                            final p = await SharedPreferences.getInstance();
                            setState(() => vibrateOn = v);
                            await p.setBool('vib', v);
                            if (notifOn) _scheduleAll();
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            body: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: (day['meals'] as List).length,
              itemBuilder: (_, i) {
                final meal = day['meals'][i];
                final id = '$dayIdx-${meal['time']}';
                final done = completed.contains(id);

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    leading: Checkbox(
                      value: done,
                      onChanged: (v) async {
                        final p = await SharedPreferences.getInstance();
                        setState(() {
                          v! ? completed.add(id) : completed.remove(id);
                        });
                        await p.setStringList('done', completed.toList());
                      },
                    ),
                    title: Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(meal['time']),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (meal['ingredients'] as String)
                              .split(', ')
                              .map((e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        const Text('• ', style: TextStyle(fontSize: 20)),
                                        Expanded(child: Text(e.trim())),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }
}
