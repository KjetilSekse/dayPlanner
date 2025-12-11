import 'meal.dart';

class Menu {
  final String id;
  final String name;
  final List<Meal> meals;

  const Menu({
    required this.id,
    required this.name,
    required this.meals,
  });

  factory Menu.fromJson(String id, Map<String, dynamic> json) {
    return Menu(
      id: id,
      name: json['name'] as String,
      meals: (json['meals'] as List).map((m) => Meal.fromJson(m)).toList(),
    );
  }
}
