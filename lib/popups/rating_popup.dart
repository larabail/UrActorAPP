// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/review_service.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/common/widgets/app_dialog.dart';
import '../main.dart';

final myController = TextEditingController(text: "");

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  bool got = false;
  int rating = 0;
  String opinion = "";
  Future<void> submit() async {
    if (reviewInfo.keys.toList().isNotEmpty) {
      await ReviewService.deleteReview(reviewId, reviewType, context);
    }
    Map<String, dynamic> information = {
      reviewId: {
        'Opinion': opinion,
        'Rating': rating.toString(),
      },
    };
    reviewInfo = information;
    await FirestoreCore.updateDocument(currentUser.uid, 'Reviews', {
      reviewType: FieldValue.arrayUnion([information])
    });
    if (reviewType == "Movies") {
      currentUser.reviews = {};
    } else {
      currentUser.tvShowReviews = {};
    }
    currentUser.allReviews.removeWhere((element) => element[0] == reviewType);
    await FirestoreCore.db
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews" &&
            (currentUser.reviews.keys.isEmpty ||
                currentUser.tvShowReviews.keys.isEmpty)) {
          Map reviewsMap = doc.data() as Map;
          List reviewsList = reviewsMap[reviewType];
          for (var element in reviewsList) {
            element = element as Map;
            if (reviewType == "Movies") {
              currentUser.reviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            } else {
              currentUser.tvShowReviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            }
            currentUser.allReviews += [
              [
                reviewType,
                element.keys.toList()[0],
                element[element.keys.toList()[0]]
              ]
            ];
          }
        }
      }
      currentUser.allReviews = currentUser.allReviews.reversed.toList();
    });
    reviewInfo = {};
    Navigator.pop(context);
  }

  void ratingStarFunction(int rating) {
    setState(() {
      this.rating = rating;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (reviewInfo.keys.toList().isNotEmpty && !got) {
      myController.text = reviewInfo["Opinion"];
      opinion = reviewInfo["Opinion"];
      ratingStarFunction(int.parse(reviewInfo["Rating"]));
      got = true;
    }
    return AppDialog(
      actions: [
        AppDialogAction(
          label: 'Not now',
          icon: Icons.close,
          tone: AppDialogTone.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Submit',
          icon: Icons.check,
          tone: AppDialogTone.confirm,
          onPressed: submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Opinion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          TextField(
            controller: myController,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your opinion',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            onChanged: (value) {
              setState(() {
                opinion = value;
              });
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Your Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Wrap(
            // The spacing used to be -6, which pulled each star back over the
            // one before it. Wrap decides where to break from the widths it is
            // given, so a negative gap let ten stars measure narrower than they
            // draw and the row ran off the edge instead of wrapping. Making the
            // buttons compact is what fits them; letting Wrap wrap is what
            // stops them clipping when a large text scale means they cannot.
            alignment: WrapAlignment.center,
            children: List.generate(
              10,
              (index) => IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 40,
                ),
                iconSize: 26,
                icon: Icon(
                  Icons.star_rate_outlined,
                  color: index < rating ? Colors.yellow[600] : Colors.white,
                ),
                onPressed: () {
                  ratingStarFunction(index + 1);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
