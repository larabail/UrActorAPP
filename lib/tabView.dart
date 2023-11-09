import 'package:flutter/material.dart';

import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
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
              if (snapshot.data!['type'] == "Movies") {
                movieResult = [
                  snapshot.data!['id'],
                  snapshot.data!['title'],
                  snapshot.data!['type'],
                ];
              } else {
                tvShowResult = [
                  snapshot.data!['id'],
                  snapshot.data!['title'],
                  snapshot.data!['type'],
                ];
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => snapshot.data!['type'] == "Movies"
                      ? const MovieResult()
                      : const TVShowResult(),
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
                  image: NetworkImage(snapshot.data!['poster']),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return const Center(child: Text("Failed to load movie details"));
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

const String api_key_actor = "?api_key=700cd4fab994df56eb41b34d38c4762a";
const String imgLink = 'https://image.tmdb.org/t/p/w500/';
String link = "https://api.themoviedb.org/3/movie/";
List<Map<String, dynamic>> movies = [];

Future<Map<String, dynamic>> getData(id, type) async {
  Map<String, dynamic> data = {};
  if (type == "TVShows") {
    link = 'https://api.themoviedb.org/3/tv/';
  } else {
    link = 'https://api.themoviedb.org/3/movie/';
  }
  final response = await http.get(Uri.parse('$link$id$api_key_actor'));
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
      data['poster'] = imgLink + json['poster_path'];
    }
    data['id'] = json['id'];
    data['type'] = type;
    print(data['type']);
    print(data['title']);
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
