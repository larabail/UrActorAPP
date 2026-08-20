import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/constants.dart';

Widget getItemContainer(
  BuildContext context,
  dynamic item,
  String type, {
  double widthPercentage = 0.28,
  double heightPercentage = 0.18,
  String? favoriteBadgeSemanticLabel,
}) {
  String imagePath = "";
  if (item!["poster_path"] != null) {
    imagePath = IMG_LINK + item!["poster_path"];
  } else if (item!["profile_path"] != null) {
    imagePath = IMG_LINK + item!["profile_path"];
  } else {
    if (type == "media") {
      imagePath = UNKNOWN_COVER;
    } else {
      imagePath = UNKNOWN_PERSON;
    }
  }

  return Container(
    margin: const EdgeInsets.fromLTRB(5.0, 10.0, 10.0, 0),
    width: MediaQuery.of(context).size.width * widthPercentage,
    height: MediaQuery.of(context).size.height * heightPercentage,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: CachedNetworkImageProvider(imagePath),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
        if (imagePath == UNKNOWN_COVER || imagePath == UNKNOWN_PERSON)
          Container(
            alignment: Alignment.center,
            child: Text(
              "${item!.containsKey("name") ? item!['name'] : item!['title']}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (favoriteBadgeSemanticLabel != null)
          Positioned(
            left: 10,
            bottom: 10,
            child: IgnorePointer(
              child: Semantics(
                label: favoriteBadgeSemanticLabel,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: Icon(
                    Icons.favorite,
                    key: const ValueKey('favoriteBadge'),
                    color: const Color.fromARGB(248, 241, 105, 56),
                    size: 18,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget getItemSelectableContainer(
    BuildContext context, dynamic item, String type, bool isSelected) {
  return SizedBox(
    width: MediaQuery.of(context).size.width * 0.28,
    height: MediaQuery.of(context).size.height * 0.18,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            image: DecorationImage(
              image: CachedNetworkImageProvider(
                item!["poster_path"] != null
                    ? IMG_LINK + item!["poster_path"]
                    : type == "media"
                        ? UNKNOWN_COVER
                        : UNKNOWN_PERSON,
              ),
              fit: BoxFit.fitWidth,
            ),
            border: isSelected
                ? Border.all(
                    color: const Color.fromARGB(250, 224, 190, 78), width: 3)
                : null,
          ),
        ),
        if (item!['poster_path'] == null)
          Container(
            alignment: Alignment.center,
            child: Text(
              "${item!.containsKey("name") ? item!['name'] : item!['title']}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}
