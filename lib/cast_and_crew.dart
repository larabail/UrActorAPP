// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/objects/Person.dart';
import 'package:uractor/person_result.dart';
import 'common/appbar.dart';
import 'common/bottom_app_bar.dart';

class CastCrew extends StatefulWidget {
  final Map data;

  const CastCrew({Key? key, required this.data}) : super(key: key);

  @override
  _CastCrewState createState() => _CastCrewState();
}

class _CastCrewState extends State<CastCrew> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "Cast & Crew",
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Cast'),
                      Tab(text: 'Crew'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        CastCrewTabView(
                            items: widget.data["cast"].reversed.toList()),
                        CastCrewTabView(
                            items: widget.data["crew"].reversed.toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: CommonBottomAppBar(-1),
    );
  }
}

class CastCrewTabView extends StatelessWidget {
  final List<dynamic> items;

  const CastCrewTabView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: (items.reversed.toList().length / 1).ceil(),
      itemBuilder: (context, index) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(1, (i) {
            final itemIndex = index * 1 + i;
            if (itemIndex < items.reversed.toList().length) {
              final item = items.reversed.toList()[itemIndex] as Map;
              return ItemCard(
                  person: Person(
                      id: item["id"].toString(),
                      name: item["name"],
                      data: item));
            }
            return const SizedBox.shrink(); // Return an empty widget if no item
          }),
        );
      },
    );
  }
}

class ItemCard extends StatelessWidget {
  final Person person;

  const ItemCard({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map>(
      future: person.getSimpleData(),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () {
              Person tempMediaItem = Person(
                  id: snapshot.data!["id"].toString(),
                  name: snapshot.data!["name"],
                  data: snapshot.data!);

              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PersonResult(
                          personResult: tempMediaItem,
                        )),
              );
            },
            child: Row(children: [
              Container(
                margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
                width: MediaQuery.of(context).size.width * 0.28,
                height: MediaQuery.of(context).size.height * 0.18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(snapshot.data!['profile_path']),
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
                        "${snapshot.data!['name']}",
                        style: const TextStyle(
                          fontSize: 14, // Adjust the font size as needed
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "as ${person.data["character"] ?? person.data["job"]}",
                        style: const TextStyle(
                          fontSize: 14, // Adjust the font size as needed
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ]),
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
