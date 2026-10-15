import 'dart:typed_data';

import '../update/update_service.dart';

/// The browser version is always the latest; nothing to install.
class PlatformInstaller implements Installer {
  @override
  bool get supported => false;

  @override
  Future<void> launch(Uint8List bytes, int version) =>
      throw UnsupportedError('Updates install themselves on Windows only');

  @override
  void quit() {}
}
