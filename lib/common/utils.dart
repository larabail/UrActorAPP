import 'dart:convert';

class Utils {
  static bool containsMap(List list, Map map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }

  static bool containsList(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == "Movies") {
        return true;
      }
    }
    return false;
  }

  static bool contains_non_type(List list, List map) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]).toString() == map[0].toString()) {
        return true;
      }
    }
    return false;
  }

  static bool contains(List list, List map, String type) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i][1]).toString() == map[1].toString() &&
          (list[i][0]) as String == type) {
        return true;
      }
    }
    return false;
  }
}


