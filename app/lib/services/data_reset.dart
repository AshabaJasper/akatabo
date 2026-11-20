import '../data/db/app_database.dart';
import '../data/seed/default_data.dart';

/// Deletes every entry, category, account, regular payment, setting and saved forecast on this
/// phone, then puts back the default categories and accounts, as on a first launch. All of it
/// happens or none of it does.
///
/// Used by "Delete everything on this phone" and by "Forgot your PIN?". It touches the database
/// only: the PIN and anything else kept outside it are cleared by their own services.
Future<void> deleteEverything(AppDatabase db) => db.transaction(() async {
  // Children before parents, so no foreign key is left pointing at a deleted row.
  await db.delete(db.transactions).go();
  await db.delete(db.regularPayments).go();
  await db.delete(db.forecastSnapshots).go();
  await db.delete(db.settings).go();
  await db.delete(db.categories).go();
  await db.delete(db.accounts).go();
  await insertDefaultData(db);
});
