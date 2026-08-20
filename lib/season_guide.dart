// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/cast_and_crew.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SeasonGuide extends StatefulWidget {
  final TVShow show;
  final Map tvShowData;

  const SeasonGuide({Key? key, required this.show, required this.tvShowData})
      : super(key: key);

  @override
  _SeasonGuideState createState() => _SeasonGuideState();
}

class _SeasonGuideState extends State<SeasonGuide> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child:
                Seasons(items: widget.tvShowData["seasons"], show: widget.show),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}

class Seasons extends StatelessWidget {
  final List<dynamic> items;
  final TVShow show;

  const Seasons({super.key, required this.items, required this.show});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: (items.reversed.toList().length / 1).ceil(),
      itemBuilder: (context, index) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(1, (i) {
            final itemIndex = index * 1 + i;
            if (itemIndex < items.length) {
              final item = items[itemIndex] as Map;
              return ItemCard(info: item, show: show);
            }
            return const SizedBox.shrink(); // Return an empty widget if no item
          }),
        );
      },
    );
  }
}

class ItemCard extends StatelessWidget {
  final Map info;
  final TVShow show;

  const ItemCard({super.key, required this.info, required this.show});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpisodeGuide(
              show: show,
              seasonData: info,
            ),
          ),
        );
      },
      child: Row(children: [
        getItemContainer(context, info, "media"),
        Column(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  "${info['name']}",
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  "${info["episode_count"]} ${S.of(context)!.episodes}",
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.1,
          child: const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              " →",
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class EpisodeGuide extends StatefulWidget {
  final TVShow show;
  final Map seasonData;

  const EpisodeGuide({Key? key, required this.show, required this.seasonData})
      : super(key: key);

  @override
  _EpisodeGuideState createState() => _EpisodeGuideState();
}

class _EpisodeGuideState extends State<EpisodeGuide> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Episodes(seasonData: widget.seasonData, show: widget.show),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}

class Episodes extends StatelessWidget {
  final Map seasonData;
  final TVShow show;
  const Episodes({super.key, required this.seasonData, required this.show});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: (seasonData["episode_count"] / 1).ceil(),
      itemBuilder: (context, index) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(1, (i) {
            final itemIndex = index * 1 + i;
            if (itemIndex < seasonData["episode_count"]) {
              return EpisodeCard(
                seasonInfo: seasonData,
                show: show,
                episode: itemIndex + 1,
              );
            }
            return const SizedBox.shrink();
          }),
        );
      },
    );
  }
}

Future<Map> getEpisodeData(id, season, episode) async {
  final String showId = id.toString();
  final response = await http.get(Uri.parse(
      '$TV_SHOW_LINK$showId/season/$season/episode/$episode$API_KEY'));
  if (response.statusCode == 200) {
    Map json = jsonDecode(response.body);
    final response2 = await http.get(Uri.parse(
        '$TV_SHOW_LINK$showId/season/$season/episode/$episode/credits$API_KEY'));
    if (response2.statusCode == 200) {
      json["cast"] = jsonDecode(response2.body)["cast"];
      json["crew"] = jsonDecode(response2.body)["crew"];
      json["guest_stars"] = jsonDecode(response2.body)["guest_stars"];
    }
    print(json["cast"]);
    return json;
  }
  return {};
}

class EpisodeCard extends StatelessWidget {
  final Map seasonInfo;
  final TVShow show;
  final int episode;

  const EpisodeCard(
      {super.key,
      required this.seasonInfo,
      required this.show,
      required this.episode});

  @override
  Widget build(BuildContext context) {
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
                width: MediaQuery.of(context).size.width * 0.28,
                height: MediaQuery.of(context).size.height * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                        snapshot.data!["still_path"] != null
                            ? IMG_LINK + snapshot.data!['still_path']
                            : UNKNOWN_COVER),
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "${S.of(context)!.episode} ${snapshot.data!["episode_number"]}",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "${snapshot.data!['name']}",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    " →",
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ]),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text(S.of(context)!.errorFailedToLoadDetails));
        } else {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.1,
              child: const Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}
