class Meal {
  final String name;
  final String time;
  final String ingredients;

  const Meal({
    required this.name,
    required this.time,
    required this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      name: json['name'] as String,
      time: json['time'] as String,
      ingredients: json['ingredients'] as String,
    );
  }

  Meal copyWith({String? name, String? time, String? ingredients}) {
    return Meal(
      name: name ?? this.name,
      time: time ?? this.time,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  List<String> get ingredientList => ingredients.split(', ').map((e) => e.trim()).toList();
}
