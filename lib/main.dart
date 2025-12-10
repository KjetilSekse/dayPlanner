import 'dart:convert'; // ← this was missing
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();

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
  List<Map<String, dynamic>> week = [];
  Set<String> completed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (week.isEmpty) _load();
  }

  Future<void> _load() async {
    final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/meals.json');
    final data = json.decode(jsonString); // now works
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      week = List.from(data['week']);
      notifOn = prefs.getBool('notif') ?? true;
      vibrateOn = prefs.getBool('vib') ?? true;
      completed = prefs.getStringList('done')?.toSet() ?? {};
    });

    if (notifOn) _scheduleAll();
  }

  Future<void> _scheduleAll() async {
    await notifications.cancelAll();
    if (!notifOn) return;

    int id = 0;
    final now = DateTime.now();

    for (int d = 0; d < week.length; d++) {
      for (var m in week[d]['meals']) {
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

  @override
  Widget build(BuildContext context) {
    if (week.isEmpty) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: PageView.builder(
        itemCount: week.length,
        itemBuilder: (_, dayIdx) {
          final day = week[dayIdx];
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
              itemCount: day['meals'].length,
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
                    title: Text(meal['name'], style: TextStyle(fontWeight: FontWeight.bold)),
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
          );
        },
      ),
    );
  }
}