import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/ak_appearance.dart';
import '../data/providers.dart';

/// The Appearance settings that shape the theme, from storage. Widget tests override this
/// with a fixed value so they need no database.
final appearanceProvider = Provider<AkAppearance>((ref) => ref.watch(storedAppearanceProvider));
