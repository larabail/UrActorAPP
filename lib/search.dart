// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../common/apiutils.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/Person.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';

String _searchTermActor = '';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  _SearchResultState createState() => _SearchResultState();
}

class _SearchResultState extends State<Search> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Create a FocusNode

  @override
  void initState() {
    super.initState();
    // Request focus when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Dispose of the controller and focus node to prevent memory leaks
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String getDefaultImagePath(String? imagePath) {
      const defaultPath =
          'https://cdn-icons-png.flaticon.com/512/3088/3088765.png';
      return imagePath == null ||
              imagePath ==
                  "https://cdn-icons-png.flaticon.com/512/3088/3088765.png"
          ? defaultPath
          : IMG_LINK + imagePath;
    }

    void handleTap(BuildContext context, Map item) {
      if (item.containsKey("poster_path") && item.containsKey("title")) {
        Movie tempMovie = Movie(
            id: item['id'].toString(),
            title: item['title'],
            coverPhoto: item['poster_path'] ?? "");
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MovieResult(
                      movie: tempMovie,
                    )));
      } else if (item.containsKey("poster_path") && item.containsKey("name")) {
        TVShow tempTvShow = TVShow(
            id: item['id'].toString(),
            title: item['name'],
            coverPhoto: item['poster_path'] ?? "");
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TVShowResult(
                      tvshow: tempTvShow,
                    )));
      } else {
        Person personResult = Person(
            id: item["id"].toString(),
            name: item["name"].toString(),
            data: item);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PersonResult(
                      personResult: personResult,
                    )));
      }
    }

    Widget buildItem(BuildContext context, Map item) {
      if (item.containsKey("poster_path") && item.containsKey("title")) {
        item['profile_path'] = getDefaultImagePath(item['poster_path']);
      } else if (item.containsKey("poster_path") && item.containsKey("name")) {
        item['profile_path'] = getDefaultImagePath(item['poster_path']);
      } else {
        item['profile_path'] = getDefaultImagePath(item['profile_path']);
      }
      return GestureDetector(
        onTap: () => handleTap(context, item),
        child: Column(
          children: [
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.height * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(item['profile_path']),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.28,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  item['title'] ??
                      (item["name"] ??
                          'Unknown'), // Replace 'title' with the appropriate key
                  style: const TextStyle(
                    fontSize: 14, // Adjust the font size as needed
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode, // Attach the FocusNode to the TextField
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Enter name of person/movie/show...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Color.fromARGB(250, 224, 190,
                          78)), // Color when the TextField is focused
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchTermActor = value;
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _searchTermActor = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List>(
              future: ApiUtils.searchData(_searchTermActor),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final people = snapshot.data!;
                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: (people.length / 3).ceil(),
                      itemBuilder: (context, index) {
                        final leftPersonIndex = index * 3;
                        final middlePersonIndex = index * 3 + 1;
                        final rightPersonIndex = index * 3 + 2;
                        final leftPerson = (leftPersonIndex < people.length)
                            ? people[leftPersonIndex]
                            : null;
                        final middlePerson = (middlePersonIndex < people.length)
                            ? people[middlePersonIndex]
                            : null;
                        final rightPerson = (rightPersonIndex < people.length)
                            ? people[rightPersonIndex]
                            : null;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (leftPerson != null)
                              buildItem(context, leftPerson),
                            if (middlePerson != null)
                              buildItem(context, middlePerson),
                            if (rightPerson != null)
                              buildItem(context, rightPerson),
                          ],
                        );
                      },
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Center(
                      child: Text("Failed to load movie details"));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
