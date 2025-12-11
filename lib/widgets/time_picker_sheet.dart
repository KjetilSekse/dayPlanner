import 'package:flutter/material.dart';
import '../models/meal.dart';

class TimePickerSheet extends StatefulWidget {
  final String dayName;
  final List<Meal> meals;
  final void Function(List<Meal> meals, bool useDefaults) onSave;

  const TimePickerSheet({
    super.key,
    required this.dayName,
    required this.meals,
    required this.onSave,
  });

  static void show({
    required BuildContext context,
    required String dayName,
    required List<Meal> meals,
    required void Function(List<Meal> meals, bool useDefaults) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TimePickerSheet(
        dayName: dayName,
        meals: meals,
        onSave: onSave,
      ),
    );
  }

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late List<Meal> _meals;

  @override
  void initState() {
    super.initState();
    _meals = widget.meals.map((m) => m.copyWith()).toList();
  }

  Future<void> _pickTime(int index) async {
    final parts = _meals[index].time.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        _meals[index] = _meals[index].copyWith(
          time: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Set Meal Times for ${widget.dayName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(_meals.length, (i) {
            return ListTile(
              title: Text(_meals[i].name),
              trailing: TextButton(
                onPressed: () => _pickTime(i),
                child: Text(_meals[i].time, style: const TextStyle(fontSize: 16)),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onSave(widget.meals, true);
                    Navigator.pop(context);
                  },
                  child: const Text('Use Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onSave(_meals, false);
                    Navigator.pop(context);
                  },
                  child: const Text('Save Times'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
