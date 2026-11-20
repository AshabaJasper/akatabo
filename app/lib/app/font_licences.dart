import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The two bundled fonts, with the licence file each ships under.
const fontLicenceFiles = {
  'Bricolage Grotesque': 'assets/fonts/OFL-BricolageGrotesque.txt',
  'Geist': 'assets/fonts/OFL-Geist.txt',
};

/// Adds the fonts' SIL Open Font Licence texts to the Open-source licences page. Packages
/// register their own licences; bundled font files do not, and the OFL asks for its text
/// to travel with the fonts.
void registerFontLicences([AssetBundle? bundle]) {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: font, value: path) in fontLicenceFiles.entries) {
      final text = await (bundle ?? rootBundle).loadString(path);
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}
