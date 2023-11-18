import 'Person.dart';

class Actor extends Person {
  Actor({
    required String id,
    required String name,
    DateTime? birthDate,
    String? biography,
  }) : super(id: id, name: name, birthDate: birthDate, biography: biography);
}
