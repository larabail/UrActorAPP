// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/cast_and_crew.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/common/media_image.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/watch_progress_controller.dart';
import 'package:uractor/common/watch_progress_view.dart';
import 'package:uractor/common/watch_progress_widgets.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/tv_show.dart';
import 'common/navigation/appbar.dart';
import 'dart:convert';
import 'common/api/http_client.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';
import 'common/navigation/app_scaffold.dart';

class SeasonGuide extends StatefulWidget {
  final TVShow show;
  final Map tvShowData;

  const SeasonGuide({super.key, required this.show, required this.tvShowData});

  @override
  State<SeasonGuide> createState() => _SeasonGuideState();
}

class _SeasonGuideState extends State<SeasonGuide> {
  late final ShowProgressController _progress;

  @override
  void initState() {
    super.initState();
    // The season list already carries every episode count TMDB knows about, so
    // the completion metadata the service needs comes free rather than costing
    // another round of requests.
    _progress = ShowProgressController(
      showId: widget.show.id.toString(),
      seasons: WatchProgressView.seasonCounts(
        widget.tvShowData["seasons"] as List?,
      ),
    );
    _progress.load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Seasons(
              items: widget.tvShowData["seasons"],
              show: widget.show,
              progress: _progress,
            ),
          ),
        ],
      ),
      selectedIndex: -1,
    );
  }
}

class Seasons extends StatelessWidget {
  final List<dynamic> items;
  final TVShow show;
  final ShowProgressController progress;

  const Seasons({
    super.key,
    required this.items,
    required this.show,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // One season per row, so the card is the list item itself. Wrapping it in
    // a Row first — a leftover from when this was a one-column grid — handed
    // the card an unbounded width, because a Row measures a non-flexible child
    // against infinity. The card's own Row has an Expanded in it, which cannot
    // be laid out against an infinite width, so every season threw during
    // layout and the whole guide came up blank.
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ItemCard(
        info: items[index] as Map,
        show: show,
        progress: progress,
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Map info;
  final TVShow show;
  final ShowProgressController progress;

  const ItemCard({
    super.key,
    required this.info,
    required this.show,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final seasonNumber =
        int.tryParse(info["season_number"]?.toString() ?? '') ?? -1;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpisodeGuide(
              show: show,
              seasonData: info,
              progress: progress,
            ),
          ),
        );
      },
      child: Row(children: [
        // A season is not a tracked media item of its own, so it gets no
        // favourite or watchlist badge: the show's membership would repeat on
        // every season tile and say nothing about the season.
        getItemContainer(context, info, "media"),
        Expanded(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  "${info['name']}",
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  "${info["episode_count"]} ${S.of(context)!.episodes}",
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              // Only worth the line once there is progress to report; an
              // untouched show would otherwise carry a "0 of 10" on every row.
              AnimatedBuilder(
                animation: progress,
                builder: (context, _) {
                  final watched = progress.watchedCountOf(seasonNumber);
                  if (watched == 0) return const SizedBox.shrink();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      S.of(context)!.watchProgressEpisodesWatched(
                            watched,
                            progress.episodeCountOf(seasonNumber),
                          ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SeasonWatchToggle(controller: progress, seasonNumber: seasonNumber),
        const Text(
          " →",
          style: TextStyle(
            fontSize: 14,
          ),
        ),
      ]),
    );
  }
}

class EpisodeGuide extends StatefulWidget {
  final TVShow show;
  final Map seasonData;
  final ShowProgressController progress;

  const EpisodeGuide({
    super.key,
    required this.show,
    required this.seasonData,
    required this.progress,
  });

  @override
  State<EpisodeGuide> createState() => _EpisodeGuideState();
}

class _EpisodeGuideState extends State<EpisodeGuide> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Episodes(
              seasonData: widget.seasonData,
              show: widget.show,
              progress: widget.progress,
            ),
          ),
        ],
      ),
      selectedIndex: -1,
    );
  }
}

class Episodes extends StatelessWidget {
  final Map seasonData;
  final TVShow show;
  final ShowProgressController progress;

  const Episodes({
    super.key,
    required this.seasonData,
    required this.show,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // The same shape, and the same reason, as [Seasons] above: the card is the
    // list item, so it is measured against the width of the list rather than
    // against infinity.
    return ListView.builder(
      itemCount: (seasonData["episode_count"] as num? ?? 0).toInt(),
      itemBuilder: (context, index) => EpisodeCard(
        seasonInfo: seasonData,
        show: show,
        episode: index + 1,
        progress: progress,
      ),
    );
  }
}

Future<Map> getEpisodeData(dynamic id, dynamic season, dynamic episode) async {
  final String showId = id.toString();
  final response = await AppHttp.client.get(Uri.parse(
      '$TV_SHOW_LINK$showId/season/$season/episode/$episode$API_KEY'));
  if (response.statusCode == 200) {
    Map json = jsonDecode(response.body);
    final response2 = await AppHttp.client.get(Uri.parse(
        '$TV_SHOW_LINK$showId/season/$season/episode/$episode/credits$API_KEY'));
    if (response2.statusCode == 200) {
      json["cast"] = jsonDecode(response2.body)["cast"];
      json["crew"] = jsonDecode(response2.body)["crew"];
      json["guest_stars"] = jsonDecode(response2.body)["guest_stars"];
    }
    debugPrint(json["cast"].toString());
    return json;
  }
  return {};
}

class EpisodeCard extends StatelessWidget {
  final Map seasonInfo;
  final TVShow show;
  final int episode;
  final ShowProgressController progress;

  const EpisodeCard(
      {super.key,
      required this.seasonInfo,
      required this.show,
      required this.episode,
      required this.progress});

  @override
  Widget build(BuildContext context) {
    final seasonNumber =
        int.tryParse(seasonInfo["season_number"]?.toString() ?? '') ?? -1;
    return FutureBuilder<Map>(
      future: getEpisodeData(show.id, seasonInfo["season_number"], episode),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CastCrew(
                    data: {
                      "cast": snapshot.data!['cast'] +
                          snapshot.data!["guest_stars"],
                      "crew": snapshot.data!['crew']
                    },
                  ),
                ),
              );
            },
            child: Row(children: [
              Container(
                margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                width: context.posterWidth,
                height: stillHeightFor(context.posterWidth),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  image: DecorationImage(
                    image: mediaImageProvider(
                        snapshot.data!["still_path"] != null
                            ? IMG_LINK + snapshot.data!['still_path']
                            : UNKNOWN_COVER),
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "${S.of(context)!.episode} ${snapshot.data!["episode_number"]}",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "${snapshot.data!['name']}",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              EpisodeWatchToggle(
                controller: progress,
                seasonNumber: seasonNumber,
                episodeNumber: episode,
              ),
              const Text(
                " →",
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            ]),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text(S.of(context)!.errorFailedToLoadDetails));
        } else {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: context.posterWidth,
              height: stillHeightFor(context.posterWidth),
              child: const Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}
