import 'dart:io';
import 'dart:typed_data';

import '../update/update_service.dart';

/// Runs a downloaded Windows installer and closes the app so it can
/// replace the program files. The installer reopens the app when done.
class PlatformInstaller implements Installer {
  @override
  bool get supported => Platform.isWindows;

  @override
  Future<void> launch(Uint8List bytes, int version) async {
    final dir = Directory('${Directory.systemTemp.path}\\ak_system_update');
    if (await dir.exists()) {
      // Installers from earlier updates; one still open stays.
      await for (final old in dir.list()) {
        try {
          await old.delete();
        } on FileSystemException catch (_) {}
      }
    }
    await dir.create(recursive: true);
    // A fresh name, so a file left locked by an earlier attempt never
    // blocks this one.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}\\AK-System-Setup-$version-$stamp.exe');
    await file.writeAsBytes(bytes, flush: true);
    await Process.start(
      file.path,
      // No questions and no message boxes; a small progress window; close
      // the app if it is still open; never restart Windows.
      const [
        '/SILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/CLOSEAPPLICATIONS',
        '/NORESTART',
      ],
      mode: ProcessStartMode.detached,
    );
  }

  @override
  void quit() => exit(0);
}
