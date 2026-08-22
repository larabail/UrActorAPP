import 'package:flutter/material.dart';
import 'package:uractor/common/credit_label.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/media_pair_membership.dart';
import 'package:uractor/common/widgets/credit_tile.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/person.dart';
import 'package:uractor/objects/tv_show.dart';
import 'common/navigation/appbar.dart';
import 'common/utils.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

class PersonResult extends StatefulWidget {
  final Person personResult;
  const PersonResult({super.key, required this.personResult});

  @override
  State<PersonResult> createState() => _PersonResultState();
}

class _PersonResultState extends State<PersonResult> {
  Widget ranking(String role, dynamic ranking, dynamic score) {
    return Text(
      "$role ${S.of(context)!.ranking}: #$ranking ($score)",
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget statsProgress(String role, int totalStats, int totalCount) {
    return Text(
      "$role ${S.of(context)!.progress}: $totalStats / $totalCount (${(((totalStats / totalCount) * 100).toStringAsFixed(2))}%)",
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget progressBar(int totalStats, int totalCount) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: LinearProgressIndicator(
        value: (totalStats) / (totalCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map stats = widget.personResult.personStats;
    return AppScaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: widget.personResult.getPersonData(currentUser, oscars),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            bool containsDirector = (snapshot.data!['movie_credits_crew'] !=
                        null &&
                    snapshot.data!['movie_credits_crew']
                        .where((c) =>
                            c["job"] != null && c["job"].contains("Director"))
                        .isNotEmpty) ||
                (snapshot.data!['tv_credits_crew'] != null &&
                    snapshot.data!['tv_credits_crew']
                        .where((c) =>
                            c["job"] != null && c["job"].contains("Director"))
                        .isNotEmpty);
            bool containsWriter = snapshot.data!['movie_credits_crew']
                        .where((c) => (c["job"].contains("Writer") ||
                            c["job"].contains("Screenplay")))
                        .length !=
                    0 ||
                snapshot.data!['tv_credits_crew']
                    .where((c) => (c["job"].contains("Writer") ||
                        c["job"].contains("Screenplay")))
                    .isNotEmpty;
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.data!['num_oscars'] != 0)
                    Center(
                      child: SizedBox(
                        height: context.posterWidth * 0.28,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              snapshot.data!['num_oscars'],
                              (index) => SizedBox(
                                height: context.posterWidth * 0.28,
                                child: Image.asset("assets/oscar2.png"),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                      // The portrait heading the page, larger than a tile in a
                      // row but the same shape. It used to be a one item
                      // ListView wrapped round a tile with its own width
                      // override, which the list's tight cross axis
                      // constraints then discarded — so the override never did
                      // anything and the portrait was whatever the list made
                      // it.
                      child: getItemContainer(
                        context,
                        snapshot.data,
                        "person",
                        scale: 1.8,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      snapshot.data!['name'],
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  ExpansionTile(
                    title: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(S.of(context)!.yourStats),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 25),
                        child: Column(
                          children: [
                            if (snapshot.data!['movie_credits_cast'].length !=
                                0)
                              ranking("Actor", snapshot.data!['actor_ranking'],
                                  stats['scoreActor']),
                            if (containsDirector)
                              ranking(
                                  "Director",
                                  snapshot.data!['director_ranking'],
                                  stats['scoreDirector']),
                            if (containsWriter)
                              ranking(
                                  "Writer",
                                  snapshot.data!['writer_ranking'],
                                  stats['scoreWriter']),
                            if (snapshot.data!['movie_credits_cast'].length !=
                                0)
                              statsProgress(
                                  "Actor",
                                  stats["stats"] + stats["stats_tv"],
                                  snapshot.data!['movie_credits_cast'].length +
                                      snapshot.data!['tv_credits_cast'].length),
                            if (snapshot.data!['movie_credits_cast'].length !=
                                0)
                              progressBar(
                                  stats["stats"] + stats["stats_tv"],
                                  snapshot.data!['movie_credits_cast'].length +
                                      snapshot.data!['tv_credits_cast'].length),
                            if (containsDirector)
                              statsProgress(
                                  "Director",
                                  stats["stats_dir"],
                                  (snapshot.data!['movie_credits_crew']
                                          .where((c) =>
                                              c["job"] != null &&
                                              c["job"].contains("Director"))
                                          .length +
                                      snapshot.data!['tv_credits_crew']
                                          .where((c) =>
                                              c["job"] != null &&
                                              c["job"].contains("Director"))
                                          .length)),
                            if (containsDirector)
                              progressBar(
                                  stats["stats_dir"],
                                  (snapshot.data!['movie_credits_crew']
                                          .where((c) =>
                                              c["job"] != null &&
                                              c["job"].contains("Director"))
                                          .length +
                                      snapshot.data!['tv_credits_crew']
                                          .where((c) =>
                                              c["job"] != null &&
                                              c["job"].contains("Director"))
                                          .length)),
                            if (containsWriter)
                              statsProgress(
                                  "Writer",
                                  stats["stats_writer_movies"] +
                                      stats["stats_writer_tv"],
                                  (snapshot.data!['movie_credits_crew']
                                          .where((c) => (c["job"]
                                                  .contains("Writer") ||
                                              c["job"].contains("Screenplay")))
                                          .length +
                                      snapshot.data!['tv_credits_crew']
                                          .where((c) => (c["job"]
                                                  .contains("Writer") ||
                                              c["job"].contains("Screenplay")))
                                          .length)),
                            if (containsWriter)
                              progressBar(
                                  stats["stats_writer_movies"] +
                                      stats["stats_writer_tv"],
                                  (snapshot.data!['movie_credits_crew']
                                          .where((c) => (c["job"]
                                                  .contains("Writer") ||
                                              c["job"].contains("Screenplay")))
                                          .length +
                                      snapshot.data!['tv_credits_crew']
                                          .where((c) => (c["job"]
                                                  .contains("Writer") ||
                                              c["job"].contains("Screenplay")))
                                          .length)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((snapshot.data!['movie_credits_crew'].length != 0 ||
                          snapshot.data!['tv_credits_crew'].length != 0) &&
                      (snapshot.data!["movie_credits_cast"].length != 0 ||
                          snapshot.data!['tv_credits_cast'].length != 0) &&
                      snapshot.data!["known_for_department"] == "Acting")
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: S.of(context)!.asCast),
                              Tab(text: S.of(context)!.asCrew),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.46,
                            child: TabBarView(
                              children: [
                                cast(context, snapshot.data),
                                crew(context, snapshot.data)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((snapshot.data!['movie_credits_crew'].length != 0 ||
                          snapshot.data!['tv_credits_crew'].length != 0) &&
                      (snapshot.data!["movie_credits_cast"].length != 0 ||
                          snapshot.data!['tv_credits_cast'].length != 0) &&
                      snapshot.data!["known_for_department"] != "Acting")
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: S.of(context)!.asCrew),
                              Tab(text: S.of(context)!.asCast),
                            ],
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.46,
                            child: TabBarView(
                              children: [
                                crew(context, snapshot.data!),
                                cast(context, snapshot.data!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((snapshot.data!['movie_credits_crew'].length == 0 &&
                          snapshot.data!['tv_credits_crew'].length == 0) &&
                      (snapshot.data!["movie_credits_cast"].length != 0 ||
                          snapshot.data!['tv_credits_cast'].length != 0))
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: cast(context, snapshot.data!),
                    ),
                  if ((snapshot.data!['movie_credits_crew'].length != 0 ||
                          snapshot.data!['tv_credits_crew'].length != 0) &&
                      (snapshot.data!["movie_credits_cast"].length == 0 &&
                          snapshot.data!['tv_credits_cast'].length == 0))
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: crew(context, snapshot.data!),
                    ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      selectedIndex: -1,
    );
  }

  /// One row of a filmography, [columns] wide.
  ///
  /// The count is passed in rather than fixed at three, because this page is
  /// as likely to be shown in a detail pane occupying half a wide window as
  /// it is to have the whole screen. Three tiles sized for a phone left most
  /// of a desktop pane empty; sizing them from the window instead overflowed
  /// the pane, which is the same mistake in the other direction.
  Widget buildMediaRow(BuildContext context, List<dynamic> mediaList, int index,
      String mediaType, bool isCrew, Map oscars,
      {required int columns}) {
    Widget buildMediaItem(dynamic media) {
      if (media == null || media["poster_path"] == null) {
        // Reserves the whole cell, margins included, so the column a
        // poster-less credit sits in stays where the rows above put it.
        return SizedBox(
          width: context.posterWidth +
              kPosterTileMarginLeft +
              kPosterTileMarginRight,
        );
      }

      return GestureDetector(
        onTap: () {
          Widget page;
          if (mediaType == 'Movies') {
            var tempMovie = Movie(
                id: media['id'].toString(),
                title: media['title'],
                coverPhoto: media['poster_path'] ?? "");
            page = MovieResult(movie: tempMovie);
          } else {
            var tempTvShow = TVShow(
                id: media['id'].toString(),
                title: media['name'],
                coverPhoto: media['poster_photo'] ?? "");
            page = TVShowResult(tvshow: tempTvShow);
          }
          openDetail(context, page);
        },
        child: creditTile(context, media, mediaType, oscars, isCrew: isCrew),
      );
    }

    return Row(
      // Packed from the leading edge so a partial last row lines up with the
      // rows above it rather than drifting to the middle.
      mainAxisAlignment: MainAxisAlignment.start,
      // Tops aligned, so a tile whose credit line is missing does not float
      // its poster down to the middle of the row.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int column = 0; column < columns; column++)
          if (index * columns + column < mediaList.length)
            buildMediaItem(mediaList[index * columns + column]),
      ],
    );
  }

  /// A filmography list that lays itself out for the width it is given.
  Widget buildMediaList(
    List<dynamic> media,
    String mediaType,
    bool isCrew,
    Map oscars,
  ) {
    return ResponsiveRegion(
      builder: (context, size) {
        final double cellWidth = context.posterWidth +
            kPosterTileMarginLeft +
            kPosterTileMarginRight;
        final int columns = gridColumnsFor(
          LayoutScope.widthOf(context),
          targetTileWidth: cellWidth,
          spacing: 0,
          minColumns: 2,
        );

        return ListView.builder(
          scrollDirection: Axis.vertical,
          itemCount: (media.length / columns).ceil(),
          itemBuilder: (context, index) => buildMediaRow(
            context,
            media,
            index,
            mediaType,
            isCrew,
            oscars,
            columns: columns,
          ),
        );
      },
    );
  }

  Widget cast(BuildContext context, dynamic data) {
    int tabCount = 0;
    if (data['movie_credits_cast'].length > 0) tabCount++;
    if (data['tv_credits_cast'].length > 0) tabCount++;

    if (tabCount == 0) {
      return Container();
    }

    List<Tab> tabs = [];
    List<Widget> tabViews = [];
    if (data['movie_credits_cast'].length > 0) {
      data['movie_credits_cast'].sort((a, b) {
        DateTime dateA = DateTime.parse(a['release_date'] != null
            ? a["release_date"] == ""
                ? "5000-01-01"
                : a['release_date']
            : "5000-01-01");
        DateTime dateB = DateTime.parse(b['release_date'] != null
            ? b["release_date"] == ""
                ? "5000-01-01"
                : b['release_date']
            : "5000-01-01");
        return dateB.compareTo(dateA);
      });

      tabs.add(Tab(text: S.of(context)!.movies));
      tabViews.add(buildMediaList(
          data['movie_credits_cast'], "Movies", false, data["oscars"]));
    }
    if (data['tv_credits_cast'].length > 0) {
      data['tv_credits_cast'].sort((a, b) {
        DateTime dateA = DateTime.parse(a['first_air_date'] != null
            ? a["first_air_date"] == ""
                ? "5000-01-01"
                : a['first_air_date']
            : "5000-01-01");
        DateTime dateB = DateTime.parse(b['first_air_date'] != null
            ? b["first_air_date"] == ""
                ? "5000-01-01"
                : b['first_air_date']
            : "5000-01-01");
        return dateB.compareTo(dateA);
      });
      tabs.add(Tab(text: S.of(context)!.tvShows));
      tabViews.add(buildMediaList(
          data['tv_credits_cast'], "TVShows", false, data["oscars"]));
    }

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          TabBar(
            unselectedLabelColor: Colors.grey,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  Widget crew(BuildContext context, dynamic data) {
    int tabCount = 0;
    if (data['movie_credits_crew'].length > 0) tabCount++;
    if (data['tv_credits_crew'].length > 0) tabCount++;

    if (tabCount == 0) {
      return Container();
    }

    List<Tab> tabs = [];
    List<Widget> tabViews = [];
    if (data['movie_credits_crew'].length > 0) {
      data['movie_credits_crew'].sort((a, b) {
        DateTime dateA = DateTime.parse(
            a['release_date'] == "" ? "5000-01-01" : a['release_date']);
        DateTime dateB = DateTime.parse(
            b['release_date'] == "" ? "5000-01-01" : b['release_date']);
        return dateB.compareTo(dateA);
      });
      tabs.add(Tab(text: S.of(context)!.movies));
      tabViews.add(buildMediaList(
          data['movie_credits_crew'], "Movies", true, data["oscars"]));
    }
    if (data['tv_credits_crew'].length > 0) {
      data['tv_credits_crew'].sort((a, b) {
        DateTime dateA = DateTime.parse(a['first_air_date'] != null
            ? a['first_air_date'] == ""
                ? "5000-01-01"
                : a['first_air_date']
            : "5000-01-01");
        DateTime dateB = DateTime.parse(b['first_air_date'] != null
            ? b['first_air_date'] == ""
                ? "5000-01-01"
                : b['first_air_date']
            : "5000-01-01");
        return dateB.compareTo(dateA);
      });
      tabs.add(Tab(text: S.of(context)!.tvShows));
      tabViews.add(buildMediaList(
          data['tv_credits_crew'], "TVShows", true, data["oscars"]));
    }

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          TabBar(
            unselectedLabelColor: Colors.grey,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  /// One poster in a filmography, with the part the person played under it.
  ///
  /// Cast and crew differ only in which field names the part, so they share
  /// this. They used to be two near-identical methods of four near-identical
  /// branches, which is how the two of them drifted apart on details like how
  /// dark the wash over a seen poster is.
  Widget creditTile(BuildContext context, dynamic media, String type, Map oscars,
      {required bool isCrew}) {
    final bool watched =
        Utils.containsNonType(currentUser.seenMovies, [type, media['id']]) ||
            Utils.containsNonType(currentUser.seenTVShows, [type, media['id']]);

    final String title = "${media['title'] ?? ''}".toLowerCase();
    final int awards =
        type == "Movies" ? (oscars[title] as List?)?.length ?? 0 : 0;

    return CreditTile(
      poster: getItemContainer(context, media, "media",
          mediaPair: mediaPairForData(media, containerType: type)),
      label: creditLabelFor(media as Map, isCrew: isCrew),
      tileWidth: context.posterWidth,
      watched: watched,
      awards: awards,
    );
  }
}
