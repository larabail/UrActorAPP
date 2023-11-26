// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/Person.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'common/constants.dart';
import 'common/utils.dart';
import 'main.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';

class PersonResult extends StatefulWidget {
  final Person personResult;
  const PersonResult({Key? key, required this.personResult}) : super(key: key);

  @override
  _PersonResultState createState() => _PersonResultState();
}

class _PersonResultState extends State<PersonResult> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: FutureBuilder<Map>(
        future: widget.personResult.getPersonData(currentUser, oscars),
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (snapshot.data!['num_oscars'] != 0)
                    Center(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.06,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              snapshot.data!['num_oscars'],
                              (index) => SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.06,
                                child: Image.asset("assets/oscar2.png"),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: MediaQuery.of(context).size.width * 0.55,
                      margin: const EdgeInsets.fromLTRB(30.0, 5.0, 30.0, 5.0),
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: 1,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              //
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.1,
                              height: MediaQuery.of(context).size.height * 0.25,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                image: DecorationImage(
                                  image: NetworkImage(snapshot
                                              .data!["profile_path"] !=
                                          null
                                      ? IMG_LINK +
                                          snapshot.data!['profile_path']
                                      : 'https://cdn-icons-png.flaticon.com/512/3088/3088765.png'),
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                            ),
                          );
                        },
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
                      title: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Your Statistics"),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 25),
                          child: Column(
                            children: [
                              Text(
                                "Actor ranking: #${snapshot.data!['actor_ranking']} (${widget.personResult.personStats['scoreActor']})",
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (widget.personResult
                                      .personStats['allDirMovies'] !=
                                  0)
                                Text(
                                  "Director ranking: #${snapshot.data!['director_ranking']} (${widget.personResult.personStats['scoreDirector']})",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Text(
                                  "Actor Movie Progress: ${widget.personResult.personStats['stats']} / ${(snapshot.data!['movie_credits_cast'].length)} (${double.parse((widget.personResult.personStats['stats'] / (snapshot.data!['movie_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['movie_credits_cast'].length !=
                                  0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: widget
                                            .personResult.personStats['stats'] /
                                        (snapshot.data!['movie_credits_cast']
                                            .length),
                                  ),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Text(
                                  "Actor TV Show Progress: ${widget.personResult.personStats['stats_tv']} / ${(snapshot.data!['tv_credits_cast'].length)} (${double.parse((widget.personResult.personStats['stats_tv'] / (snapshot.data!['tv_credits_cast'].length) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (snapshot.data!['tv_credits_cast'].length != 0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: widget.personResult
                                            .personStats['stats_tv'] /
                                        (snapshot
                                            .data!['tv_credits_cast'].length),
                                  ),
                                ),
                              if (widget.personResult
                                      .personStats['allDirMovies'] !=
                                  0)
                                Text(
                                  "Director Progress: ${widget.personResult.personStats['stats_dir']} / ${(snapshot.data!['allDirMovies'])} (${double.parse((widget.personResult.personStats['stats_dir'] / (snapshot.data!['allDirMovies']) * 100).toStringAsFixed(2))}%)",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              if (widget.personResult
                                      .personStats["allDirMovies"] !=
                                  0)
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: LinearProgressIndicator(
                                    value: widget.personResult
                                            .personStats['stats_dir'] /
                                        (snapshot.data!['allDirMovies']),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                  if ((snapshot.data!['movie_credits_crew'].length != 0 ||
                          snapshot.data!['tv_credits_crew'].length != 0) &&
                      (snapshot.data!["movie_credits_cast"].length != 0 ||
                          snapshot.data!['tv_credits_cast'].length != 0) &&
                      snapshot.data!["known_for_department"] == "Acting")
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: 'As Part of the Cast'),
                              Tab(text: 'As Part of the Crew'),
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
                          const TabBar(
                            labelColor: null,
                            unselectedLabelColor: null,
                            tabs: [
                              Tab(text: 'As Part of the Crew'),
                              Tab(text: 'As Part of the Cast'),
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
            return const Center(
              child: Text("Failed to load movie details"),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }

  Widget buildMediaRow(BuildContext context, List<dynamic> mediaList, int index,
      String mediaType, bool isCrew) {
    int leftIndex = index * 3;
    int middleIndex = index * 3 + 1;
    int rightIndex = index * 3 + 2;

    Widget buildMediaItem(dynamic media) {
      if (media == null || media["poster_path"] == null) return Container();

      return GestureDetector(
        onTap: () {
          MaterialPageRoute route;
          if (mediaType == 'Movies') {
            var tempMovie = Movie(
                id: media['id'].toString(),
                title: media['title'],
                coverPhoto: media['poster_path'] ?? "");
            route = MaterialPageRoute(
                builder: (context) => MovieResult(movie: tempMovie));
          } else {
            var tempTvShow = TVShow(
                id: media['id'].toString(),
                title: media['name'],
                coverPhoto: media['poster_photo'] ?? "");
            route = MaterialPageRoute(
                builder: (context) => TVShowResult(tvshow: tempTvShow));
          }
          Navigator.push(context, route);
        },
        child: isCrew
            ? seenCrew(context, media, mediaType)
            : seen(context, media, mediaType),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (leftIndex < mediaList.length) buildMediaItem(mediaList[leftIndex]),
        if (middleIndex < mediaList.length)
          buildMediaItem(mediaList[middleIndex]),
        if (rightIndex < mediaList.length)
          buildMediaItem(mediaList[rightIndex]),
      ],
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
      tabs.add(const Tab(text: 'Movies'));
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['movie_credits_cast'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(
            context, data['movie_credits_cast'], index, "Movies", false),
      ));
    }
    if (data['tv_credits_cast'].length > 0) {
      tabs.add(const Tab(text: 'TV Shows'));
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['tv_credits_cast'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(
            context, data['tv_credits_cast'], index, "TVShows", false),
      ));
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
      tabs.add(const Tab(text: 'Movies'));
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['movie_credits_crew'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(
            context, data['movie_credits_crew'], index, "Movies", true),
      ));
    }
    if (data['tv_credits_crew'].length > 0) {
      tabs.add(const Tab(text: 'TV Shows'));
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['tv_credits_crew'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(
            context, data['tv_credits_crew'], index, "TVShows", true),
      ));
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

  seen(BuildContext context, movie, type) {
    if (!Utils.contains_non_type(currentUser.seenMovies, [type, movie['id']]) &&
        !Utils.contains_non_type(
            currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
                  const Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['character']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  seenCrew(BuildContext context, movie, type) {
    if (!Utils.contains_non_type(currentUser.seenMovies, [type, movie['id']]) &&
        !Utils.contains_non_type(
            currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                  const Color.fromARGB(255, 255, 255, 255).withOpacity(.5),
                ],
              ),
              image: DecorationImage(
                image: NetworkImage(IMG_LINK + movie['poster_path']),
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10.0, 10.0, 5.0, 0),
            width: MediaQuery.of(context).size.width * 0.28,
            height: MediaQuery.of(context).size.height * 0.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.75),
                  const Color.fromARGB(0, 255, 255, 255).withOpacity(0),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(54.0, 10.0, 5.0, 0),
                  width: MediaQuery.of(context).size.width * 0.15,
                  height: MediaQuery.of(context).size.height * 0.05,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/seen_after.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.14,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: SizedBox(
                    height: 20.0,
                    width: MediaQuery.of(context).size.width * 0.26,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            "${movie['job']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}
