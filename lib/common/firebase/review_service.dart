import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';
import 'package:uractor/objects/media.dart';
import 'package:uractor/popups/rating_popup.dart';

class ReviewService {
  /// Opens a dialog to allow the user to write a review.
  /// @param id The media ID.
  /// @param type The media type.
  /// @param context The UI context.
  /// @return A Future indicating if the dialog was completed.
  static Future<bool> writeReview(dynamic id, String type, BuildContext context) {
    reviewId = id.toString();
    reviewType = type;
    Completer<bool> completer = Completer();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    ).then((value) => completer.complete(true));
    return completer.future;
  }

  /// Opens a dialog to allow the user to edit an existing review.
  /// @param id The media ID.
  /// @param type The media type.
  /// @param context The UI context.
  /// @return A Future indicating if the dialog was completed.
  static Future<bool> editReview(dynamic id, String type, BuildContext context) {
    reviewId = id.toString();
    reviewType = type;

    Completer<bool> completer = Completer();
    if (type == "Movies") {
      reviewInfo = currentUser.reviews[id.toString()];
    } else {
      reviewInfo = currentUser.tvShowReviews[id.toString()];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const RatingDialog();
      },
    ).then((value) => completer.complete(true));
    return completer.future;
  }

  /// Deletes a review from Firestore and updates local cache.
  /// @param id The media ID.
  /// @param type The media type.
  /// @param context The UI context.
  /// @return True if the review was successfully deleted.
  static Future<bool> deleteReview(dynamic id, String type, BuildContext context) async {
    reviewInfo = {};
    reviewed = false;
    await FirestoreCore.db
        .collection(currentUser.uid)
        .get()
        .then((QuerySnapshot querySnapshot) async {
      for (var doc in querySnapshot.docs) {
        if (doc.id == "Reviews") {
          Map reviewsMap = doc.data() as Map;
          List reviewsInList = reviewsMap[type] as List;
          List tempReviewsInList = [];
          for (var element in reviewsInList) {
            element = element as Map;
            if (element.keys.toList()[0].toString() != id.toString()) {
              tempReviewsInList.add(element);
            }
          }
          await FirestoreCore.updateDocument(
              currentUser.uid, "Reviews", {type: tempReviewsInList});
          if (type == "Movies") {
            currentUser.reviews = {};
          } else {
            currentUser.tvShowReviews = {};
          }

          currentUser.allReviews.removeWhere((element) => element[0] == type);
          for (var element in tempReviewsInList) {
            element = element as Map;
            if (type == "Movies") {
              currentUser.reviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            } else {
              currentUser.tvShowReviews[element.keys.toList()[0]] =
                  element[element.keys.toList()[0]];
            }
            currentUser.allReviews += [
              [
                type,
                element.keys.toList()[0],
                element[element.keys.toList()[0]]
              ]
            ];
          }
        }
      }
    });
    return true;
  }

  /// Retrieves a specific user's review of a given media item.
  /// @param uid The user ID.
  /// @param mediaItem The media item.
  /// @param type The media type ("movie" or "TVShows").
  /// @return The review data as a Map.
  static Future<Map> getReviewByUser(
      String uid, MediaItem mediaItem, String type) async {
    type = type == "movie" ? "Movies" : "TVShows";
    Map reviewDocInfo = await FirestoreCore.getDocumentData(uid, "Reviews");
    List reviewData = reviewDocInfo["data"][type];
    Map review = reviewData
        .where((element) => element.keys.toList()[0] == mediaItem.id)
        .first;
    return review;
  }
}
