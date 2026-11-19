/// Turns a description into the key used to match payees: lower case, letters and digits
/// only, single spaces. "Groceries, Nakasero  market" and "groceries nakasero market"
/// match. No Flutter imports: the Python reference in ml/ does the same.
library;

final _notWord = RegExp(r'[^a-z0-9]+');

String payeeKeyOf(String description) => description.toLowerCase().replaceAll(_notWord, ' ').trim();
