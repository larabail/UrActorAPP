import 'package:flutter/material.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/Movie.dart';
import 'package:uractor/objects/Person.dart';
import 'package:uractor/objects/TVShow.dart';
import 'common/navigation/appbar.dart';
import 'common/navigation/bottom_app_bar.dart';
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
  Widget ranking(role, ranking, score) {
    return Text(
      "$role ${S.of(context)!.ranking}: #$ranking ($score)",
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget statsProgress(role, totalStats, totalCount) {
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
    return Scaffold(
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
                              child: getItemContainer(
                                  context, snapshot.data, "person",
                                  widthPercentage: 0.1,
                                  heightPercentage: 0.25));
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
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }

  Widget buildMediaRow(BuildContext context, List<dynamic> mediaList, int index,
      String mediaType, bool isCrew, Map oscars) {
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
            ? seenCrew(context, media, mediaType, oscars)
            : seen(context, media, mediaType, oscars),
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
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['movie_credits_cast'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(context,
            data['movie_credits_cast'], index, "Movies", false, data["oscars"]),
      ));
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
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['tv_credits_cast'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(context,
            data['tv_credits_cast'], index, "TVShows", false, data["oscars"]),
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
      data['movie_credits_crew'].sort((a, b) {
        DateTime dateA = DateTime.parse(
            a['release_date'] == "" ? "5000-01-01" : a['release_date']);
        DateTime dateB = DateTime.parse(
            b['release_date'] == "" ? "5000-01-01" : b['release_date']);
        return dateB.compareTo(dateA);
      });
      tabs.add(Tab(text: S.of(context)!.movies));
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['movie_credits_crew'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(context,
            data['movie_credits_crew'], index, "Movies", true, data["oscars"]),
      ));
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
      tabViews.add(ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: (data['tv_credits_crew'].length / 3).ceil(),
        itemBuilder: (context, index) => buildMediaRow(context,
            data['tv_credits_crew'], index, "TVShows", true, data["oscars"]),
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

  Stack seen(BuildContext context, movie, type, oscars) {
    if (!Utils.contains_non_type(currentUser.seenMovies, [type, movie['id']]) &&
        !Utils.contains_non_type(
            currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          getItemContainer(context, movie, "media"),
          if (type == "Movies" &&
              oscars.containsKey(movie["title"].toLowerCase()))
            Align(
              alignment: Alignment.bottomCenter,
              child: Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        oscars[movie["title"].toLowerCase()].length,
                        (index) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Image.asset("assets/oscar2.png"),
                        ),
                      ),
                    ),
                  ),
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
          getItemContainer(context, movie, "media"),
          Container(
            margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
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
          if (type == "Movies" &&
              oscars.containsKey(movie["title"].toLowerCase()))
            Align(
              alignment: Alignment.bottomCenter,
              child: Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        oscars[movie["title"].toLowerCase()].length,
                        (index) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Image.asset("assets/oscar2.png"),
                        ),
                      ),
                    ),
                  ),
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

  Stack seenCrew(BuildContext context, movie, type, oscars) {
    if (!Utils.contains_non_type(currentUser.seenMovies, [type, movie['id']]) &&
        !Utils.contains_non_type(
            currentUser.seenTVShows, [type, movie['id']])) {
      return Stack(
        children: [
          getItemContainer(context, movie, "media"),
          if (type == "Movies" &&
              oscars.containsKey(movie["title"].toLowerCase()))
            Align(
              alignment: Alignment.bottomCenter,
              child: Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        oscars[movie["title"].toLowerCase()].length,
                        (index) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Image.asset("assets/oscar2.png"),
                        ),
                      ),
                    ),
                  ),
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
          getItemContainer(context, movie, "media"),
          Container(
            margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
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
          if (type == "Movies" &&
              oscars.containsKey(movie["title"].toLowerCase()))
            Align(
              alignment: Alignment.bottomCenter,
              child: Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        oscars[movie["title"].toLowerCase()].length,
                        (index) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06,
                          child: Image.asset("assets/oscar2.png"),
                        ),
                      ),
                    ),
                  ),
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
