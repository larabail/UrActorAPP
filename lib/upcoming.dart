// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';
import 'package:uractor/common/utils.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';
import 'movie_result.dart';

class Upcoming extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "Upcoming Movies",
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: FutureBuilder<List>(
                future: ApiUtils.getUpcomingMovies(),
                builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemCount: (snapshot.data!.length / 3).ceil(),
                      itemBuilder: (context, index) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(3, (i) {
                            final itemIndex = index * 3 + i;
                            if (itemIndex < snapshot.data!.toList().length) {
                              final item = snapshot.data!.toList()[itemIndex];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => MovieResult(
                                              movie: item,
                                            )),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      5.0, 10.0, 10.0, 0),
                                  width:
                                      MediaQuery.of(context).size.width * 0.28,
                                  height:
                                      MediaQuery.of(context).size.height * 0.18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(27),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          IMG_LINK + item.coverPhoto),
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox
                                .shrink(); // Return an empty widget if no item
                          }),
                        );
                      },
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
            ),
          )
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}
