// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/review_service.dart';
import '../main.dart';

final myController = TextEditingController(text: "");

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key});

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  bool got = false;
  int rating = 0;
  String opinion = "";
  Future<void> submit() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
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
    var userDoc = firestore.collection(currentUser.uid).doc('Reviews');
    await userDoc.update({
      reviewType: FieldValue.arrayUnion([information])
    });
    if (reviewType == "Movies") {
      currentUser.reviews = {};
    } else {
      currentUser.tvShowReviews = {};
    }
    currentUser.allReviews.removeWhere((element) => element[0] == reviewType);
    await FirebaseFirestore.instance
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: ListBody(
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
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
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
                spacing: -6,
                children: List.generate(
                  10,
                  (index) => IconButton(
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      submit();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                          SizedBox(width: 5),
                          Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.close, color: Colors.red),
                          SizedBox(width: 5),
                          Text(
                            'Not now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
