/// The Settings search, as plain Dart so it can be tested without a screen.
///
/// The hub lists [SearchableSetting]s; [filterSettings] keeps the ones a typed term matches.
library;

/// What the search reads from one Settings entry.
abstract interface class SearchableSetting {
  /// The entry's name, as shown on its row.
  String get label;

  /// The line under the name saying what the page holds.
  String get description;

  /// Other words a person might type for this page, never shown.
  List<String> get keywords;
}

/// The entries of [entries] that [query] matches, in their original order.
///
/// Matching ignores case and extra spaces. Each word of the query must appear somewhere in the
/// entry's label, description or keywords, so "back up" and "backup restore" both find Data
/// and backup. An empty or blank query matches everything.
List<T> filterSettings<T extends SearchableSetting>(List<T> entries, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return List.of(entries);
  return [
    for (final entry in entries)
      if (_matches(entry, words)) entry,
  ];
}

bool _matches(SearchableSetting entry, List<String> words) {
  final text = [entry.label, entry.description, ...entry.keywords].join(' ').toLowerCase();
  return words.every(text.contains);
}
