import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/main.dart';

class RecommendationService {
  /// Updates the user's media recommendations in Firestore.
  /// @param newRecommendations A list of media recommendations.
  /// @param type The media type (Movies or TVShows).
  static Future<void> updateRecommendations(
      List newRecommendations, String type) async {
    Map recommendations =
        await FirestoreCore.getDocumentData(currentUser.uid, "Recommendations");
    DocumentReference recommendationsDoc = recommendations["snapshot"];
    Map<String, dynamic> recommendationsData = recommendations["data"];
    if (type == "Movies") {
      recommendationsData["Movies"] = newRecommendations;
    } else {
      recommendationsData["TVShows"] = newRecommendations;
    }
    currentUser.recommendations = recommendationsData;
    recommendationsDoc.update(recommendationsData);
  }
}
