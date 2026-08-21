import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/media_image.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/tv_show.dart';
import 'package:uractor/tvshow_result.dart';

import 'main.dart';
import 'objects/media.dart';
import 'common/firebase/firestore_core.dart';
import 'common/layout/responsive.dart';
import 'common/layout/two_pane.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> refreshNotifications() async {
    var notificationDoc = await FirestoreCore.db
        .collection(currentUser.uid)
        .doc("Notifications")
        .get();
    Map<String, dynamic> data = notificationDoc.data() as Map<String, dynamic>;
    currentUser.notifications = data;
    setState(() {
      currentUser.notifications = currentUser.notifications;
    });
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      WriteBatch batch = FirestoreCore.db.batch();
      for (var notificationKey in currentUser.notifications.keys) {
        var notification = currentUser.notifications[notificationKey];
        if (!notification['read']) {
          DocumentReference notificationRef =
              FirestoreCore.db.collection(currentUser.uid).doc("Notifications");
          var notificationsData = await notificationRef.get();
          var notifications = notificationsData.data() as Map<String, dynamic>;
          notifications[notificationKey]["read"] = true;
          notificationRef.set(notifications);
        }
      }
      await batch.commit();

      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        for (var notificationKey in currentUser.notifications.keys) {
          currentUser.notifications[notificationKey]['read'] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final message = '${S.of(context)!.errorNotification}: $e';
      debugPrint(message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.notifications),
      ),
      body: RefreshIndicator(
        onRefresh: refreshNotifications,
        child: ListView.builder(
          itemCount: currentUser.notifications.keys.toList().length,
          itemBuilder: (context, index) {
            String notificationKey = currentUser.notifications.keys
                .toList()
                .reversed
                .toList()[index];
            var notification = currentUser.notifications[notificationKey];
            String type;
            if (notification["type"] == "movie") {
              type = S.of(context)!.movie;
            } else {
              type = S.of(context)!.show;
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
              child: SizedBox(
                height: 125,
                child: GestureDetector(
                  onTap: () {
                    MediaItem tempItem;
                    if (notification["type"] == "movie") {
                      tempItem = Movie(
                          id: notification["id"],
                          title: notification["title"],
                          coverPhoto: notification["coverPhoto"]);
                    } else {
                      tempItem = TVShow(
                          id: notification["id"],
                          title: notification["title"],
                          coverPhoto: notification["coverPhoto"]);
                    }
                    openDetail(
                        context,
                        notification["type"] == "movie"
                            ? MovieResult(movie: tempItem as Movie)
                            : TVShowResult(tvshow: tempItem as TVShow));
                  },
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: context.posterWidth,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(27),
                              image: DecorationImage(
                                image: mediaImageProvider(
                                  notification["coverPhoto"] as String?,
                                ),
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Text(
                              '${notification["sender"]["username"]} ${S.of(context)!.notificationMessage} $type "${notification['title']}"',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!notification['read'])
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              S.of(context)!.newNotification,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
