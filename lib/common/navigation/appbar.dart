// custom_app_bar.dart
import 'package:flutter/material.dart';

import '../../popups/settings_pop_up.dart';
import '../../search.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'UrActor',
        style: TextStyle(
          fontFamily: 'Futura', // Replace with your font name
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Search()),
            );
          },
          child: const Icon(Icons.search),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const InfoButtonDialog(),
            );
          },
          child: const Icon(Icons.settings),
        ),
        const SizedBox(
            width: 16), // Optional: to add some space on the right side
      ],
    );
  }
}
