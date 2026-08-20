import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uractor/main.dart';
import 'package:uractor/l10n/l10n.dart';

import './firestore_core.dart';

class CalendarService {
  /// Prompts the user to confirm they watched the item today and adds it to their calendar.
  /// @param id The media ID.
  /// @param title The title of the media.
  /// @param runtime The runtime in minutes.
  /// @param imdbRating The IMDB rating.
  /// @param today The current date.
  /// @param context The UI context.
  /// @return True if the user confirmed and it was added.
  static Future<bool> addtoCalendar(String id, String title, int runtime,
      double imdbRating, DateTime today, BuildContext context) async {
    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: Text(S.of(context)!.confirmWatchedToday),
          actions: <Widget>[
            TextButton(
              child: Text(S.of(context)!.cancel),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(S.of(context)!.yes),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed) {
      final myObject = {
        today.toString().split(" ")[0]: FieldValue.arrayUnion([
          {'id': id, 'title': title, 'runtime': runtime, 'rating': imdbRating}
        ])
      };

      await FirestoreCore.updateDocument(currentUser.uid, 'Calendar', myObject);
      currentUser.calendar = {};
      await FirestoreCore.db
          .collection(currentUser.uid)
          .get()
          .then((QuerySnapshot querySnapshot) {
        for (final doc in querySnapshot.docs) {
          if (doc.id == "Calendar") {
            currentUser.calendar = doc.data() as Map;
          }
        }
      });
      return true;
    }
    return false;
  }

  /// Deletes a calendar entry for a user and optionally for their friends.
  /// @param uid The user ID.
  /// @param id The media ID.
  /// @param title The media title.
  /// @param date The calendar date to delete from.
  /// @param context The UI context.
  static Future<void> deleteFromCalendar(String uid, String id, String title,
      String date, BuildContext context) async {
    bool? deleteForEveryone = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context)!.deleteCalendarEntry),
          content: Text(S.of(context)!.deleteCalendarEntryQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Just me
              child: Text(S.of(context)!.justMe),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // For everyone
              child: Text(S.of(context)!.everyone),
            ),
          ],
        );
      },
    );
    Map calendarDocInfo = await FirestoreCore.getDocumentData(uid, "Calendar");
    Map calendarData = calendarDocInfo["data"];

    // The entry records who it was watched with. That list is who "everyone"
    // means -- not the full friend list, which would also wipe the entry from
    // friends who logged the same title on the same day independently.
    List watchedWith = [];
    if (calendarData[date] is List) {
      for (Map entry in List.from(calendarData[date])) {
        if (entry['id'].toString() == id.toString() &&
            entry['title'].toString() == title.toString()) {
          watchedWith = List.from(entry['friends'] ?? [])..remove(uid);
          break;
        }
      }
    }

    if (deleteForEveryone == true && watchedWith.isNotEmpty) {
      await deleteFromFriendsCalendar(id, title, date, watchedWith);
    }
    Map<Object, Object> updatedCalendar = {};
    for (String key in calendarData.keys) {
      if (key == date) {
        if (calendarData[key].length == 1) {
          var movie = calendarData[key][0];
          if (movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString()) {
            calendarData[key] = [];
          }
        } else {
          List movies = calendarData[key];

          int movieIndex = movies.indexWhere((movie) =>
              movie['id'].toString() == id.toString() &&
              movie['title'].toString() == title.toString());

          if (movieIndex != -1) {
            movies.removeAt(movieIndex);
          }
          break;
        }
      }
    }
    for (String key in calendarData.keys) {
      if (calendarData[key].isNotEmpty) {
        updatedCalendar[key] = calendarData[key];
      } else {
        updatedCalendar[key] = [];
      }
    }
    if (uid == currentUser.uid) {
      currentUser.calendar = Map<String, List>.from(calendarData);
    }
    await FirestoreCore.updateDocument(uid, "Calendar", updatedCalendar);
  }

  /// Deletes a calendar entry from the calendars of the friends it was
  /// watched with.
  /// @param id The media ID.
  /// @param title The title of the media.
  /// @param date The date of the calendar entry.
  /// @param friendUids The friends the entry was shared with.
  static Future<void> deleteFromFriendsCalendar(
      String id, String title, String date, List friendUids) async {
    for (String friendUid in friendUids.cast<String>()) {
      Map calendarDocInfo =
          await FirestoreCore.getDocumentData(friendUid, "Calendar");
      Map calendarData = calendarDocInfo["data"];

      if (!calendarData.containsKey(date)) continue;

      List movies = List.from(calendarData[date]); // Avoid mutating directly
      int movieIndex = movies.indexWhere((movie) =>
          movie['id'].toString() == id.toString() &&
          movie['title'].toString() == title.toString());

      if (movieIndex == -1) continue;

      movies.removeAt(movieIndex);

      // update() only writes the keys it is handed, so dropping the date key
      // from a copy of the map left the original array untouched on the
      // server -- which is why removing the last entry of a day silently did
      // nothing. Write the emptied list for this one date instead.
      await FirestoreCore.updateDocument(friendUid, "Calendar", {date: movies});
    }
  }

  /// Updates the calendar for a given date range or specific date with new data.
  /// @param dateRange The date range string (e.g., "YYYY-MM-DD to YYYY-MM-DD").
  /// @param uid The user ID.
  /// @param newData The data to insert.
  /// @param dateForMap The single date string to use if dateRange is empty.
  static Future<void> updateCalendar(
      String dateRange, String uid, Map newData, String dateForMap) async {
    if (dateRange != "") {
      DateTime startDate = DateTime.parse(dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        await FirestoreCore.updateDocument(uid, "Calendar", {
          dateStr: FieldValue.arrayUnion([newData])
        });
      }
    } else {
      await FirestoreCore.updateDocument(uid, "Calendar", {
        dateForMap: FieldValue.arrayUnion([newData])
      });
    }
  }

  /// Updates the current user's local calendar object with new data.
  /// @param dateRange The date range string.
  /// @param newData The calendar entry data.
  /// @param dateForMap The single fallback date if range is empty.
  static void updateCurrentUserCalendar(
      String dateRange, Map newData, String dateForMap) {
    if (dateRange != "") {
      DateTime startDate = DateTime.parse(dateRange.split("T")[0]);
      DateTime endDate = DateTime.parse(dateRange.split("T")[2]);

      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateStr = date.toIso8601String().split("T")[0];
        if (currentUser.calendar.keys.toList().contains(dateStr)) {
          currentUser.calendar[dateStr].add(newData);
        } else {
          currentUser.calendar[dateStr] = [
            newData,
          ];
        }
      }
    } else {
      if (currentUser.calendar.keys.toList().contains(dateForMap)) {
        currentUser.calendar[dateForMap].add(newData);
      } else {
        currentUser.calendar[dateForMap] = [
          newData,
        ];
      }
    }
  }

  // Can I add this to the updateCurrentUserCalendar function? Instead of making it a whole new one?
  /// Writes the current user's local calendar object to Firestore.
  static Future<void> updateCurrentUserCalendarDocument() async {
    Map<Object, Object> updatedCalendar = {};
    for (String key in currentUser.calendar.keys) {
      updatedCalendar[key] = currentUser.calendar[key];
    }
    await FirestoreCore.updateDocument(
        currentUser.uid, "Calendar", updatedCalendar);
  }
}
