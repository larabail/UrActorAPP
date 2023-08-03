// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'movie_result.dart';
import 'main.dart';

final myController = TextEditingController(text: "");

class RatingDialog extends StatefulWidget {
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
      await deleteReview(reviewId, context);
    }
    Map<String, dynamic> information = {
      reviewId: {
        'Opinion': opinion,
        'Rating': rating.toString(),
      },
    };
    reviewInfo = information;
    var userDoc = firestore.collection(uid).doc('Reviews');
    await userDoc.update({
      'Seen': FieldValue.arrayUnion([information])
    });
    reviews = {};
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews" && reviews.keys.isEmpty) {
          Map reviewsMap = doc.data() as Map;
          List reviewsList = reviewsMap["Seen"];
          for (var element in reviewsList) {
            element = element as Map;
            reviews[element.keys.toList()[0]] =
                element[element.keys.toList()[0]];
          }
        }
      }
    });
    reviewInfo = {};
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => MovieResult()));
  }

  Future<void> deleteReview(id, context) async {
    reviews.remove(id.toString());
    reviewed = false;
    await FirebaseFirestore.instance
        .collection(uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews") {
          Map allreviews = doc.data() as Map;
          List reviewsInList = allreviews["Seen"] as List;
          List tempReviewsInList = [];
          for (var element in reviewsInList) {
            element = element as Map;
            if (element.keys.toList()[0].toString() != id.toString()) {
              tempReviewsInList.add(element);
            }
          }
          final userDoc =
              FirebaseFirestore.instance.collection(uid).doc("Reviews");
          await userDoc.update({'Seen': tempReviewsInList});
        }
      }
    });
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
          color: const Color.fromARGB(
              255, 23, 20, 20), // change the color of dialog window here
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
                ),
              ),
              TextField(
                controller: myController,
                style: const TextStyle(
                  fontSize: 16,
                ),
                onChanged: (value) {
                  setState(() {
                    opinion = value;
                  });
                },
              ), // Text input field
              const SizedBox(height: 10),
              const Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
                  ElevatedButton(
                    onPressed: () {
                      submit();
                    },
                    child: const Text('Submit'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Not now'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
