// ignore_for_file: no_leading_underscores_for_local_identifiers, use_key_in_widget_constructors, must_be_immutable, non_constant_identifier_names

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/l10n/l10n.dart';
import '/objects/media.dart';
import '/objects/movie.dart';
import '/objects/tv_show.dart';
import 'common/navigation/appbar.dart';
import 'common/utils.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'main.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

class Reviews extends StatefulWidget {
  const Reviews();

  @override
  State<Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<Reviews> {
  List<Map<String, dynamic>> movies = [];
  final Map<String, Future<Map<String, dynamic>>> _mediaFutures = {};

  Future<Map<String, dynamic>> getData(dynamic id, String type) {
    final key = '$type:$id';
    return _mediaFutures.putIfAbsent(key, () async {
      try {
        return await Utils.fetchMediaData(id, type, movies);
      } catch (_) {
        return {
          'id': id,
          'type': type,
          'title': null,
          'poster_path': null,
          'missing': true,
        };
      }
    });
  }

  String _posterUrl(Map data) {
    final posterPath = data['poster_path'];
    if (posterPath is String && posterPath.isNotEmpty) {
      return IMG_LINK + posterPath;
    }
    return UNKNOWN_COVER;
  }

  Widget buildReviewTile(
      BuildContext context, Map review, String type, String id) {
    return FutureBuilder<Map<String, dynamic>>(
        future: getData(id, type),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data!;
            final mediaType = data['type']?.toString() ?? type;
            final mediaId = data['id']?.toString() ?? id;
            final title = data['title']?.toString() ?? S.of(context)!.unknown;
            final canOpenDetails = data['missing'] != true;

            return ExpansionTile(
              title: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: canOpenDetails
                          ? () {
                              MediaItem tempItem;
                              if (mediaType == "Movies") {
                                tempItem = Movie(
                                    id: mediaId,
                                    title: title,
                                    coverPhoto: data['poster_path'] ?? "");
                              } else {
                                tempItem = TVShow(
                                    id: mediaId,
                                    title: title,
                                    coverPhoto: data['poster_path'] ?? "");
                              }
                              openDetail(
                                  context,
                                  mediaType == "Movies"
                                      ? MovieResult(
                                          movie: tempItem as Movie,
                                        )
                                      : TVShowResult(
                                          tvshow: tempItem as TVShow,
                                        ));
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                        width: context.posterWidth,
                        height: posterHeightFor(context.posterWidth),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(_posterUrl(data)),
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        wordSpacing: 1,
                        height: 1.5,
                      ),
                    ),
                  ]),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.45,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 26, 25, 25),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          S.of(context)!.opinion(review["Opinion"] ?? ""),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          S.of(context)!.rating(review["Rating"] ?? ""),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            wordSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: () async {
                                  await ReviewService.editReview(
                                      mediaId, mediaType, context);
                                  setState(() {
                                    currentUser.reviews = currentUser.reviews;
                                  });
                                },
                                icon: const Icon(Icons.edit)),
                            IconButton(
                                onPressed: () async {
                                  await ReviewService.deleteReview(
                                      mediaId, mediaType, context);

                                  setState(() {
                                    currentUser.allReviews =
                                        currentUser.allReviews;
                                  });
                                },
                                icon: const Icon(Icons.delete)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Container(
                margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                width: context.posterWidth,
                height: posterHeightFor(context.posterWidth),
                child: const Center(child: CircularProgressIndicator()));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      detailPlaceholder: DetailPanePlaceholder(
        message: S.of(context)!.detailPanePlaceholder,
      ),
      appBar: const CustomAppBar(),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            S.of(context)!.yourSection(S.of(context)!.reviews),
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DefaultTabController(
          length: 2,
          child: Expanded(
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Movies'),
                    Tab(text: 'TV Shows'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView.builder(
                        itemCount: (currentUser.reviews.length / 2).ceil(),
                        itemBuilder: (BuildContext context, int index) {
                          final leftReviewIndex = index * 2;
                          final rightReviewIndex = index * 2 + 1;
                          final leftReviewId =
                              (leftReviewIndex < currentUser.reviews.length)
                                  ? currentUser.reviews.keys
                                      .toList()
                                      .reversed
                                      .toList()[leftReviewIndex]
                                  : null;
                          final rightReviewId =
                              (rightReviewIndex < currentUser.reviews.length)
                                  ? currentUser.reviews.keys
                                      .toList()
                                      .reversed
                                      .toList()[rightReviewIndex]
                                  : null;
                          final leftReview = (leftReviewId != null)
                              ? (currentUser.reviews.values
                                  .toList()
                                  .reversed
                                  .toList()[leftReviewIndex])
                              : null;
                          final rightReview = (rightReviewId != null)
                              ? (currentUser.reviews.values
                                  .toList()
                                  .reversed
                                  .toList()[rightReviewIndex])
                              : null;
                          return Row(
                            children: [
                              if (leftReview != null)
                                Expanded(
                                  child: buildReviewTile(context, leftReview,
                                      'Movies', leftReviewId),
                                ),
                              if (rightReview != null)
                                Expanded(
                                  child: buildReviewTile(context, rightReview,
                                      'Movies', rightReviewId),
                                ),
                            ],
                          );
                        },
                      ),
                      ListView.builder(
                        itemCount:
                            (currentUser.tvShowReviews.length / 2).ceil(),
                        itemBuilder: (BuildContext context, int index) {
                          final leftReviewIndex = index * 2;
                          final rightReviewIndex = index * 2 + 1;
                          final leftReviewId = (leftReviewIndex <
                                  currentUser.tvShowReviews.length)
                              ? currentUser.tvShowReviews.keys
                                  .toList()
                                  .reversed
                                  .toList()[leftReviewIndex]
                              : null;
                          final rightReviewId = (rightReviewIndex <
                                  currentUser.tvShowReviews.length)
                              ? currentUser.tvShowReviews.keys
                                  .toList()
                                  .reversed
                                  .toList()[rightReviewIndex]
                              : null;
                          final leftReview = (leftReviewId != null)
                              ? (currentUser.tvShowReviews.values
                                  .toList()
                                  .reversed
                                  .toList()[leftReviewIndex])
                              : null;
                          final rightReview = (rightReviewId != null)
                              ? (currentUser.tvShowReviews.values
                                  .toList()
                                  .reversed
                                  .toList()[rightReviewIndex])
                              : null;
                          return Row(
                            children: [
                              if (leftReview != null)
                                Expanded(
                                  child: buildReviewTile(context, leftReview,
                                      "TVShows", leftReviewId),
                                ),
                              if (rightReview != null)
                                Expanded(
                                  child: buildReviewTile(context, rightReview,
                                      "TVShows", rightReviewId),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      ]),
      selectedIndex: -1,
    );
  }
}
