import 'package:flutter/material.dart';
import '../models/menu.dart';

class MenuPicker extends StatelessWidget {
  final String dayName;
  final Map<String, Menu> menus;
  final String currentMenuId;
  final void Function(String menuId) onMenuSelected;

  const MenuPicker({
    super.key,
    required this.dayName,
    required this.menus,
    required this.currentMenuId,
    required this.onMenuSelected,
  });

  static void show({
    required BuildContext context,
    required String dayName,
    required Map<String, Menu> menus,
    required String currentMenuId,
    required void Function(String menuId) onMenuSelected,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => MenuPicker(
        dayName: dayName,
        menus: menus,
        currentMenuId: currentMenuId,
        onMenuSelected: onMenuSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Menu for $dayName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...menus.entries.map((entry) {
          final isSelected = entry.key == currentMenuId;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.green : null,
            ),
            title: Text(entry.value.name),
            onTap: () {
              Navigator.pop(context);
              onMenuSelected(entry.key);
            },
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
