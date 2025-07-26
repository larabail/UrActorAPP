import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/movie_result.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/TVShow.dart';
import 'package:uractor/tvshow_result.dart';

import 'main.dart';
import 'objects/Media.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> refreshNotifications() async {
    var NotificationDoc = await FirebaseFirestore.instance
        .collection(currentUser.uid)
        .doc("Notifications")
        .get();
    Map<String, dynamic> data = NotificationDoc.data() as Map<String, dynamic>;
    currentUser.notifications = data;
    setState(() {
      currentUser.notifications = currentUser.notifications;
    });
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var notificationKey in currentUser.notifications.keys) {
        var notification = currentUser.notifications[notificationKey];
        if (!notification['read']) {
          DocumentReference notificationRef = FirebaseFirestore.instance
              .collection(currentUser.uid)
              .doc("Notifications");
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
      print('${S.of(context)!.errorNotification}: $e');
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => notification["type"] == "movie"
                            ? MovieResult(movie: tempItem as Movie)
                            : TVShowResult(tvshow: tempItem as TVShow),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                            width: MediaQuery.of(context).size.width * 0.28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(27),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  notification["coverPhoto"],
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
