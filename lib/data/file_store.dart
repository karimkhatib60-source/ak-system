import 'dart:typed_data';

/// Where the bytes of attached files are kept on this device, outside the
/// database: a folder on Android and Windows, the browser's own storage on
/// the web. Files are named by their attachment id.
abstract class FileStore {
  Future<void> put(String id, Uint8List bytes);

  /// The file, or null when this device does not have it.
  Future<Uint8List?> get(String id);

  Future<void> remove(String id);
}

/// Keeps files in memory. Used in tests, and when the device's storage
/// cannot be opened.
class MemoryFileStore implements FileStore {
  final _files = <String, Uint8List>{};

  @override
  Future<void> put(String id, Uint8List bytes) async => _files[id] = bytes;

  @override
  Future<Uint8List?> get(String id) async => _files[id];

  @override
  Future<void> remove(String id) async => _files.remove(id);
}

/// Attachment ids are used as file names; anything else is refused.
bool isSafeFileId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);
