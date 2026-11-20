import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Where a finished export goes. The person chooses each time, so the app never writes to a
/// folder of its own choosing and needs no storage permission.
abstract interface class ExportDestination {
  /// Opens the system "save as" dialog. True when the file was saved, false when the person
  /// closed the dialog.
  Future<bool> save({required Uint8List bytes, required String fileName, required String mimeType});

  /// Opens the share sheet with the file attached. True unless the person dismissed it.
  /// [origin] is the screen area the sheet points from on a tablet.
  Future<bool> share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    Rect? origin,
  });
}

/// The phone's own dialogs: Android's document picker (Storage Access Framework) through
/// `flutter_file_dialog`, and the share sheet through `share_plus`.
class SystemExportDestination implements ExportDestination {
  const SystemExportDestination();

  @override
  Future<bool> save({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final path = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(data: bytes, fileName: fileName, mimeTypesFilter: [mimeType]),
    );
    return path != null;
  }

  @override
  Future<bool> share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        title: fileName,
        sharePositionOrigin: origin,
      ),
    );
    // Android reports "unavailable" when it cannot tell what was picked; the sheet was shown.
    return result.status != ShareResultStatus.dismissed;
  }
}

/// Tests replace this with a fake that records what it was given.
final exportDestinationProvider = Provider<ExportDestination>(
  (ref) => const SystemExportDestination(),
);
