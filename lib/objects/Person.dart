class Person {
  final String name;
  final DateTime? birthDate;
  final String? biography;

  Person({
    required String id,
    required this.name,
    this.birthDate,
    this.biography,
  });
}
