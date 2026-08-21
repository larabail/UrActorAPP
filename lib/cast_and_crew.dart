// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/person.dart';
import 'package:uractor/person_result.dart';
import 'common/navigation/appbar.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

class CastCrew extends StatefulWidget {
  final Map data;

  const CastCrew({super.key, required this.data});

  @override
  State<CastCrew> createState() => _CastCrewState();
}

class _CastCrewState extends State<CastCrew> {
  @override
  Widget build(BuildContext context) {
    List essentialRoles = ["Director", "Writer"];

    List sortedCrew = List.from(widget.data["crew"]);
    sortedCrew.sort((a, b) {
      List rolesA =
          (a["job"] ?? "").split('/').map((role) => role.trim()).toList();
      List rolesB =
          (b["job"] ?? "").split('/').map((role) => role.trim()).toList();

      int indexA = rolesA.indexWhere((role) => essentialRoles.contains(role));
      int indexB = rolesB.indexWhere((role) => essentialRoles.contains(role));

      if (indexA == -1) indexA = essentialRoles.length;
      if (indexB == -1) indexB = essentialRoles.length;

      return indexA.compareTo(indexB);
    });

    return AppScaffold(
      detailPlaceholder: DetailPanePlaceholder(
        message: S.of(context)!.detailPanePlaceholder,
      ),
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              S.of(context)!.labelCastAndCrew,
              style: const TextStyle(
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
                  TabBar(
                    tabs: [
                      Tab(text: S.of(context)!.cast),
                      Tab(text: S.of(context)!.crew),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        CastCrewTabView(
                            items: widget.data["cast"].reversed.toList()),
                        CastCrewTabView(items: sortedCrew.reversed.toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      selectedIndex: -1,
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
            return const SizedBox.shrink();
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

              openDetail(
                  context,
                  PersonResult(
                    personResult: tempMediaItem,
                  ));
            },
            child: Row(children: [
              getItemContainer(context, snapshot.data, "person"),
              Column(
                children: [
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        "${S.of(context)!.as} ${person.data["character"] ?? person.data["job"] ?? ""}",
                        style: const TextStyle(
                          fontSize: 14,
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
              width: context.posterWidth,
              height: posterHeightFor(context.posterWidth),
              child:
                  Center(child: Text(S.of(context)!.errorFailedToLoadDetails)));
        } else {
          return Container(
              margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
              width: context.posterWidth,
              height: posterHeightFor(context.posterWidth),
              child: const Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}
