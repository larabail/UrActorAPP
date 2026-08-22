/// What a person did on a title, as one line of text.
///
/// Kept apart from the widget that draws it because the interesting part is
/// which field to believe, and that can be checked without a screen.
library;

/// The line naming the person's part in [credit].
///
/// TMDB fills in `character` for a cast credit and `job` for a crew one, but
/// a person's combined credits mix both kinds in one list and neither field is
/// guaranteed to be there — an uncredited walk-on arrives with `character` set
/// to the empty string, and a few crew entries carry a character instead of a
/// job. [isCrew] says which field to believe first; the other is tried after
/// it rather than being ignored, since a wrong-looking label still says more
/// than a blank one.
///
/// Returns the empty string when there is nothing to say. The page used to
/// interpolate the raw field, so a credit missing it printed the literal word
/// "null" across the poster.
String creditLabelFor(Map credit, {required bool isCrew}) {
  final String? preferred = _line(credit[isCrew ? 'job' : 'character']);
  if (preferred != null) return preferred;
  return _line(credit[isCrew ? 'character' : 'job']) ?? '';
}

/// [value] as a single trimmed line, or null if it holds nothing readable.
///
/// TMDB occasionally puts a newline inside a character name — "Self /
/// Narrator" arrives wrapped in some records — and a line break in a
/// one-line label draws as a blank box rather than as a second row.
String? _line(dynamic value) {
  if (value == null) return null;
  final String text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.isEmpty ? null : text;
}
