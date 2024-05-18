import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/objects/Media.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/TVShow.dart';

// import 'main.dart';
import '../movie_result.dart';
import '../tvshow_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyTabView extends StatelessWidget {
  final List<dynamic> favItems;

  const MyTabView({super.key, required this.favItems});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: (favItems.reversed.toList().length / 3).ceil(),
      itemBuilder: (context, index) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(3, (i) {
            final itemIndex = index * 3 + i;
            if (itemIndex < favItems.reversed.toList().length) {
              final item = favItems.reversed.toList()[itemIndex];
              return ItemCard(item: item);
            }
            return const SizedBox.shrink(); // Return an empty widget if no item
          }),
        );
      },
    );
  }
}

class ItemCard extends StatelessWidget {
  final List<dynamic> item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getData(item[1], item[0]),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () {
              // Handle the click event here
              MediaItem tempMediaItem;
              if (snapshot.data!['type'] == "Movies") {
                tempMediaItem = Movie(
                    id: snapshot.data!['id'].toString(),
                    title: snapshot.data!['title'],
                    coverPhoto: snapshot.data!['poster'] ?? "");
              } else {
                tempMediaItem = TVShow(
                    id: snapshot.data!['id'].toString(),
                    title: snapshot.data!['title'],
                    coverPhoto: snapshot.data!['poster'] ?? "");
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => snapshot.data!['type'] == "Movies"
                      ? MovieResult(
                          movie: tempMediaItem as Movie,
                        )
                      : TVShowResult(
                          tvshow: tempMediaItem as TVShow,
                        ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(snapshot.data!['poster']),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              child: const Center(child: Text("Failed to load movie details")));
        } else {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              child: const Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}

List<Map<String, dynamic>> movies = [];

Future<Map<String, dynamic>> getData(id, type) async {
  Map<String, dynamic> data = {};
  String link;
  if (type == "TVShows") {
    link = TV_SHOW_LINK;
  } else {
    link = MOVIE_LINK;
  }
  final response = await http.get(Uri.parse('$link$id$API_KEY'));
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    if (type == "TVShows") {
      data['title'] = json['name'];
    } else {
      data['title'] = json['title'];
    }
    if (json['poster_path'] == null) {
      data['poster'] = 'assets/question_mark.png';
    } else {
      data['poster'] = IMG_LINK + json['poster_path'];
    }
    data['id'] = json['id'];
    data['type'] = type;
    if (!containsMap(movies, data)) {
      movies.add(data);
    }
  } else {
    throw Exception('Failed to load movie details');
  }
  return data;
}

bool containsMap(List<Map<String, dynamic>> list, Map<String, dynamic> map) {
  String jsonString = json.encode(map);
  for (int i = 0; i < list.length; i++) {
    if (json.encode(list[i]) == jsonString) {
      return true;
    }
  }
  return false;
}
