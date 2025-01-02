// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:uractor/common/item_container.dart';
import '../common/apiutils.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/Person.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void handleTap(BuildContext context, Map item, String typeContainer) {
      if (item.containsKey("poster_path") && item.containsKey("title") && typeContainer == "media") {
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
      } else if (item.containsKey("poster_path") && item.containsKey("name") && typeContainer == "media") {
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
      String typeContainer = "media";
      if (item.containsKey("poster_path") &&
          (item.containsKey("title") || item.containsKey("name"))) {
        item['poster_path'] = item['poster_path'];
      } else {
        typeContainer = "person";
        item['poster_path'] = item['profile_path'];
      }
      return GestureDetector(
        onTap: () => handleTap(context, item, typeContainer),
        child: Column(
          children: [
            getItemContainer(context, item, typeContainer),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.28,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  item['title'] ?? (item["name"] ?? 'Unknown'),
                  style: const TextStyle(
                    fontSize: 14,
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
              focusNode: _focusNode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Enter name of person/movie/show...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: Color.fromARGB(250, 224, 190, 78)),
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
