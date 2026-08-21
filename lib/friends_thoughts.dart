import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/common/firebase/social_service.dart';
import 'package:uractor/friends_profile.dart';
import 'package:uractor/l10n/l10n.dart';

import 'common/navigation/appbar.dart';
import 'objects/media.dart';
import 'common/navigation/app_scaffold.dart';

class FriendsThoughts extends StatefulWidget {
  final Map friends;
  final MediaItem mediaItem;
  final String type;
  final Map data;

  const FriendsThoughts(
      {super.key,
      required this.friends,
      required this.mediaItem,
      required this.type,
      required this.data});

  @override
  State<FriendsThoughts> createState() => _FriendsThoughtsState();
}

class _FriendsThoughtsState extends State<FriendsThoughts> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Text(
              S.of(context)!.friendsThoughts(widget.mediaItem.title),
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Center(
              child: ListView.builder(
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  String friendUid =
                      widget.friends.keys.toList()[index].split("-")[0];
                  String friendUsername =
                      widget.friends.keys.toList()[index].split("-")[1];
                  String profilePath = widget.friends.values.toList()[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FriendProfile(friendUid: friendUid),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(left: 16.0, top: 10),
                                child: ClipOval(
                                  child: profilePath != ""
                                      ? Image.network(
                                          profilePath,
                                          height: 30,
                                          width: 30,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          'assets/main_profile.png',
                                          height: 30,
                                          width: 30,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: Text(
                                  friendUsername,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              FutureBuilder(
                                future: SocialService.favedBy(widget.mediaItem,
                                    friendUid, "Favorites", "Movies"),
                                builder: ((context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 32.0,
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  } else if (snapshot.hasError) {
                                    return SizedBox(
                                      height: 32.0,
                                      child: Text(S
                                          .of(context)!
                                          .errorFailedToLoadFavorites),
                                    );
                                  } else if (snapshot.hasData) {
                                    if (snapshot.data! == true) {
                                      return Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          margin: const EdgeInsets.fromLTRB(
                                              0.0, 10.0, 10.0, 10.0),
                                          child: Image.asset(
                                            'assets/fav_after.png',
                                            height: 20,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                }),
                              )
                            ],
                          ),
                        ),
                        FutureBuilder(
                          future: ReviewService.getReviewByUser(
                              friendUid, widget.mediaItem, widget.type),
                          builder: ((context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 32.0,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            } else if (snapshot.hasError) {
                              return SizedBox(
                                height: 32.0,
                                child: Center(
                                    child: Text(S
                                        .of(context)!
                                        .friendLeftNoReview(friendUsername))),
                              );
                            } else if (snapshot.hasData) {
                              String opinion = snapshot
                                  .data![widget.mediaItem.id]["Opinion"];
                              String rating =
                                  snapshot.data![widget.mediaItem.id]["Rating"];
                              return Text("'$opinion. $rating / 10'");
                            } else {
                              return const SizedBox.shrink();
                            }
                          }),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      selectedIndex: -1,
    );
  }
}
