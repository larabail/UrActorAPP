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
    Map<String, dynamic> recommendationsData = recommendations["data"];
    if (type == "Movies") {
      recommendationsData["Movies"] = newRecommendations;
    } else {
      recommendationsData["TVShows"] = newRecommendations;
    }
    currentUser.recommendations = recommendationsData;
    await FirestoreCore.updateDocument(
        currentUser.uid, "Recommendations", recommendationsData);
  }
}
