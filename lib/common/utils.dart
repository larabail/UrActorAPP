import 'dart:convert';

class Utils {
  static bool containsMap(
      List<Map<String, dynamic>> list, Map<String, dynamic> map) {
    String jsonString = json.encode(map);
    for (int i = 0; i < list.length; i++) {
      if (json.encode(list[i]) == jsonString) {
        return true;
      }
    }
    return false;
  }
}
