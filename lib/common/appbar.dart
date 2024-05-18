import 'package:flutter/material.dart';
import 'package:uractor/main.dart';

import '../notifications.dart';
import '../popups/settings_pop_up.dart';
import '../search.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  _CustomAppBarState createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  @override
  void initState() {
    super.initState();
    currentUser.unreadNotificationsCount.addListener(_updateState);
  }

  @override
  void dispose() {
    currentUser.unreadNotificationsCount.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'UrActor',
        style: TextStyle(
          fontFamily: 'Futura',
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Notifications()),
            );
          },
          child: Stack(
            children: [
              Icon(
                currentUser.unreadNotificationsCount.value > 0
                    ? Icons.notifications
                    : Icons.notifications_none,
              ),
              if (currentUser.unreadNotificationsCount.value > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '${currentUser.unreadNotificationsCount.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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
        const SizedBox(width: 16),
      ],
    );
  }
}
