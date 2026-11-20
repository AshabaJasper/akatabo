import 'backup_codec.dart';

/// How the person chose to restore.
enum RestoreMode {
  /// Keeps this phone's rows and adds the backup's rows that are not here. When a row is on
  /// both, the one changed last (newer `updatedAt`) wins.
  addMissing,

  /// Makes this phone hold exactly what the backup holds.
  replaceAll,
}

/// What a restore would do, worked out before anything changes. Plain Dart: it compares
/// JSON rows by id, so it is tested without a database.
class RestorePlan {
  RestorePlan._(this.mode, this.upserts, this.deletes);

  final RestoreMode mode;

  /// Rows to write, by table. A row whose id is here already is updated in place.
  final Map<String, List<Map<String, Object?>>> upserts;

  /// Keys of this phone's rows to remove, by table (only when replacing).
  final Map<String, List<String>> deletes;

  /// True when it would change nothing.
  bool get isEmpty =>
      upserts.values.every((r) => r.isEmpty) && deletes.values.every((d) => d.isEmpty);
}

/// What the Restore screen shows: what is in the backup, how it overlaps with this phone,
/// and what each choice would add or lose. Transactions are "entries" to the person.
class RestorePreview {
  const RestorePreview({
    required this.backupTransactions,
    required this.backupCategories,
    required this.backupBudgets,
    required this.backupFirstDay,
    required this.backupLastDay,
    required this.phoneTransactions,
    required this.phoneFirstDay,
    required this.phoneLastDay,
    required this.phoneOnly,
    required this.phoneOnlyFirstDay,
    required this.phoneOnlyLastDay,
    required this.toAdd,
    required this.toUpdate,
    required this.phoneNewer,
    required this.otherChanges,
  });

  final int backupTransactions;

  /// Categories the person can see and change (Fees and tax, a system category, is left out).
  final int backupCategories;

  /// Categories with a monthly budget.
  final int backupBudgets;
  final int? backupFirstDay;
  final int? backupLastDay;

  final int phoneTransactions;
  final int? phoneFirstDay;
  final int? phoneLastDay;

  /// Entries on this phone that the backup does not have, and their days. Kept by "Add what
  /// is missing", lost by "Replace everything".
  final int phoneOnly;
  final int? phoneOnlyFirstDay;
  final int? phoneOnlyLastDay;

  /// Entries "Add what is missing" would add.
  final int toAdd;

  /// Entries on both where the backup's copy was changed later, so it would replace this
  /// phone's copy (with either choice).
  final int toUpdate;

  /// Entries on both where this phone's copy was changed later. "Add what is missing" keeps
  /// this phone's copy; "Replace everything" puts the backup's older copy back.
  final int phoneNewer;

  /// Rows other than entries (categories, accounts, regular payments, settings, saved
  /// forecasts) that "Add what is missing" would add or update.
  final int otherChanges;

  /// Entries that "Replace everything" would lose: those only on this phone.
  int get lostByReplacing => phoneOnly;

  /// The figure on the restore button: entries added, or every entry when replacing.
  int restoreCount(RestoreMode mode) => mode == RestoreMode.addMissing ? toAdd : backupTransactions;

  /// Whether "Add what is missing" would change anything at all.
  bool get addMissingChangesSomething => toAdd + toUpdate + otherChanges > 0;
}

/// Compares a backup with this phone, row by row.
///
/// [keepOnPhone] names setting keys that belong to this phone and are never taken from a
/// file nor removed (backup times, the app lock).
class RestorePlanner {
  RestorePlanner({required this.backup, required this.phone, bool Function(String)? keepOnPhone})
    : _keepOnPhone = keepOnPhone ?? ((_) => false);

  final BackupTables backup;
  final BackupTables phone;
  final bool Function(String) _keepOnPhone;

  /// The identity of a row: its id, a setting's key, or a saved forecast's month and day.
  static String keyOf(String table, Map<String, Object?> row) => switch (table) {
    'settings' => '${row['key']}',
    'forecastSnapshots' => '${row['periodStart']}/${row['takenOn']}',
    _ => '${row['id']}',
  };

  /// When a row was last changed, in milliseconds. Saved forecasts never change after they
  /// are taken, so their creation time is used.
  static int stampOf(String table, Map<String, Object?> row) {
    final v = row[table == 'forecastSnapshots' ? 'createdAt' : 'updatedAt'];
    return v is int ? v : 0;
  }

  /// A row never changed since it was made: created and updated at the same moment. On
  /// a phone this is a default row seeded on the first day (or after "Delete everything"),
  /// stamped later than any backup, so the plain "newer wins" rule would keep the blank
  /// default over the person's edited copy (a balance, a budget, a new name).
  static bool _untouched(String table, Map<String, Object?> row) =>
      table != 'forecastSnapshots' &&
      row['createdAt'] is int &&
      row['createdAt'] == row['updatedAt'];

  /// Whether the backup's copy of a row replaces this phone's: it is newer, or the phone's
  /// copy was never edited and the backup's was.
  static bool _backupWins(String table, Map<String, Object?> row, Map<String, Object?> here) {
    final a = stampOf(table, row);
    final b = stampOf(table, here);
    return a > b || (a != b && _untouched(table, here) && !_untouched(table, row));
  }

  bool _local(String table, Map<String, Object?> row) =>
      table == 'settings' && _keepOnPhone('${row['key']}');

  List<Map<String, Object?>> _rows(BackupTables t, String table) => [
    for (final r in t[table] ?? const <Map<String, Object?>>[])
      if (!_local(table, r)) r,
  ];

  Map<String, Map<String, Object?>> _byKey(BackupTables t, String table) => {
    for (final r in _rows(t, table)) keyOf(table, r): r,
  };

  RestorePlan plan(RestoreMode mode) {
    final upserts = <String, List<Map<String, Object?>>>{};
    final deletes = <String, List<String>>{};
    for (final table in BackupFormat.tables) {
      final mine = _byKey(phone, table);
      final theirs = _byKey(backup, table);
      upserts[table] = [
        for (final MapEntry(:key, value: row) in theirs.entries)
          if (mode == RestoreMode.replaceAll ||
              !mine.containsKey(key) ||
              _backupWins(table, row, mine[key]!))
            row,
      ];
      deletes[table] = [
        if (mode == RestoreMode.replaceAll)
          for (final key in mine.keys)
            if (!theirs.containsKey(key)) key,
      ];
    }
    return RestorePlan._(mode, upserts, deletes);
  }

  RestorePreview preview() {
    const tx = 'transactions';
    final mine = _byKey(phone, tx);
    final theirs = _byKey(backup, tx);
    int? day(Map<String, Object?> r) => r['localDay'] is int ? r['localDay'] as int : null;
    (int?, int?) range(Iterable<Map<String, Object?>> rows) {
      int? first;
      int? last;
      for (final d in rows.map(day).whereType<int>()) {
        if (first == null || d < first) first = d;
        if (last == null || d > last) last = d;
      }
      return (first, last);
    }

    var toUpdate = 0;
    var phoneNewer = 0;
    for (final MapEntry(:key, value: row) in theirs.entries) {
      final here = mine[key];
      if (here == null) continue;
      if (_backupWins(tx, row, here)) {
        toUpdate++;
      } else if (stampOf(tx, here) > stampOf(tx, row)) {
        phoneNewer++;
      }
    }
    final phoneOnlyRows = [
      for (final MapEntry(:key, :value) in mine.entries)
        if (!theirs.containsKey(key)) value,
    ];
    final merge = plan(RestoreMode.addMissing);
    final otherChanges = [
      for (final t in BackupFormat.tables)
        if (t != tx) merge.upserts[t]!.length,
    ].fold(0, (a, b) => a + b);

    final categories = _rows(backup, 'categories').where((c) => c['isSystem'] != true);
    final (bFirst, bLast) = range(theirs.values);
    final (pFirst, pLast) = range(mine.values);
    final (oFirst, oLast) = range(phoneOnlyRows);
    return RestorePreview(
      backupTransactions: theirs.length,
      backupCategories: categories.length,
      backupBudgets: categories.where((c) => c['monthlyBudget'] != null).length,
      backupFirstDay: bFirst,
      backupLastDay: bLast,
      phoneTransactions: mine.length,
      phoneFirstDay: pFirst,
      phoneLastDay: pLast,
      phoneOnly: phoneOnlyRows.length,
      phoneOnlyFirstDay: oFirst,
      phoneOnlyLastDay: oLast,
      toAdd: theirs.keys.where((k) => !mine.containsKey(k)).length,
      toUpdate: toUpdate,
      phoneNewer: phoneNewer,
      otherChanges: otherChanges,
    );
  }
}
