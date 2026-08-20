import 'package:flutter/material.dart';

Future<bool> runVisibleAsyncAction(
  BuildContext context,
  Future<void> Function() action,
  String errorMessage,
) async {
  try {
    await action();
    return true;
  } catch (error, stackTrace) {
    debugPrint('Async action failed: $error\n$stackTrace');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
    return false;
  }
}
