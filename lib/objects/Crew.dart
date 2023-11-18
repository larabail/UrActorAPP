import 'Person.dart';

class Crew extends Person {
  Crew({
    required String id,
    required String name,
    DateTime? birthDate,
    String? biography,
  }) : super(id: id, name: name, birthDate: birthDate, biography: biography);
}
