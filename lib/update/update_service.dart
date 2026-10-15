import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_version.dart';

/// Runs a downloaded installer. Only the Windows app can.
abstract class Installer {
  bool get supported;

  /// Saves the installer and starts it.
  Future<void> launch(Uint8List bytes, int version);

  /// Closes the app, so the installer can replace its files.
  void quit();
}

/// A newer version published on GitHub Releases.
class Release {
  const Release({
    required this.version,
    required this.notes,
    required this.installer,
    required this.size,
    this.sha256,
  });

  final int version;

  /// What changed, in plain words (the release description).
  final String notes;
  final Uri installer;
  final int size;

  /// The installer's checksum, when GitHub gives one.
  final String? sha256;

  /// Reads GitHub's "latest release" answer; null when it has no Windows
  /// installer (yet) or the tag is not a version.
  static Release? fromGitHub(Map<String, Object?> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final version = versionOfTag('${json['tag_name'] ?? ''}');
    if (version == null) return null;
    final assets = (json['assets'] as List?) ?? const [];
    for (final a in assets.whereType<Map<String, Object?>>()) {
      if (a['name'] != installerAsset) continue;
      final url = Uri.tryParse('${a['browser_download_url'] ?? ''}');
      final size = (a['size'] as num?)?.toInt() ?? 0;
      if (url == null || url.scheme != 'https' || size <= 0) return null;
      final digest = a['digest'];
      return Release(
        version: version,
        notes: '${json['body'] ?? ''}'.trim(),
        installer: url,
        size: size,
        sha256: digest is String && digest.startsWith('sha256:')
            ? digest.substring(7).toLowerCase()
            : null,
      );
    }
    return null;
  }
}

/// "v11" or "v11.0.0" gives 11.
int? versionOfTag(String tag) {
  final m = RegExp(r'^v?(\d+)(\.\d+)*$').firstMatch(tag.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

enum UpdateState {
  idle,
  checking,
  upToDate,
  ready,
  downloading,
  installing,
  failed,
}

/// Keeps the Windows app up to date: looks for a newer release on start and
/// every few hours, and installs it when the owner says so. Data is kept in
/// the user's own folder, so an update never touches it.
class UpdateService extends ChangeNotifier {
  UpdateService({
    required this.installer,
    http.Client? client,
    this.currentVersion = appVersion,
    this.repo = releaseRepo,
  }) : _http = client ?? http.Client();

  final Installer installer;
  final int currentVersion;
  final String repo;
  final http.Client _http;

  /// Called before the installer starts, to send any changes to the cloud.
  Future<void> Function()? beforeInstall;

  /// Called after the installer started, just before the app closes, to
  /// close the database.
  Future<void> Function()? beforeQuit;

  UpdateState state = UpdateState.idle;
  Release? available;

  /// Share of the download done, 0 to 1.
  double progress = 0;
  String? problem;
  bool dismissed = false;

  Timer? _first;
  Timer? _periodic;

  bool get supported => installer.supported;

  void start() {
    if (!supported) return;
    _first = Timer(const Duration(seconds: 8), check);
    _periodic = Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  void _set(UpdateState s, {String? problem}) {
    state = s;
    this.problem = problem;
    notifyListeners();
  }

  /// The releases page, for installing by hand.
  Uri get releasesPage => Uri.https('github.com', '/$repo/releases/latest');

  /// Set when Windows did not let a downloaded installer start, so the
  /// owner can install it by hand from [releasesPage].
  bool blocked = false;

  bool get _busy =>
      state == UpdateState.checking ||
      state == UpdateState.downloading ||
      state == UpdateState.installing;

  Future<http.Response> _get(String path) => _http
      .get(
        Uri.https('api.github.com', path),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'AK-System',
        },
      )
      .timeout(const Duration(seconds: 20));

  /// Looks for a newer version. Being offline just means nothing to install
  /// for now.
  Future<void> check() async {
    if (!supported || _busy) return;
    _set(UpdateState.checking);
    try {
      final res = await _get('/repos/$repo/releases/latest');
      if (res.statusCode == 404) {
        // No release yet is fine; a repository that cannot be found means
        // updates can never arrive, which the owner must be told.
        final home = await _get('/repos/$repo');
        available = null;
        return home.statusCode == 200
            ? _set(UpdateState.upToDate)
            : _set(
                UpdateState.failed,
                problem:
                    'The update page github.com/$repo cannot be found, so '
                    'new versions cannot arrive. Please tell Claude.',
              );
      }
      if (res.statusCode != 200) {
        return _set(
          available != null ? UpdateState.ready : UpdateState.failed,
          problem: 'Could not check for updates (${res.statusCode}).',
        );
      }
      final r = Release.fromGitHub(
        (jsonDecode(res.body) as Map).cast<String, Object?>(),
      );
      if (r != null && r.version > currentVersion) {
        if (available?.version != r.version) {
          dismissed = false;
          blocked = false;
        }
        available = r;
        _set(UpdateState.ready);
      } else {
        available = null;
        _set(UpdateState.upToDate);
      }
    } catch (_) {
      _set(
        available != null ? UpdateState.ready : UpdateState.failed,
        problem: 'Could not check for updates. Check the internet connection.',
      );
    }
  }

  /// Downloads the new version, checks it is complete and intact, then runs
  /// the installer, which closes the app and opens it again.
  Future<void> install() async {
    final r = available;
    if (r == null || !supported || _busy) return;
    progress = 0;
    _set(UpdateState.downloading);
    final Uint8List data;
    try {
      final res = await _http
          .send(http.Request('GET', r.installer))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw _UpdateError('The download failed (${res.statusCode}).');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 60),
      )) {
        bytes.add(chunk);
        progress = (bytes.length / r.size).clamp(0, 1).toDouble();
        notifyListeners();
      }
      data = bytes.takeBytes();
      if (data.length != r.size) {
        throw _UpdateError('The download was incomplete. Please try again.');
      }
      if (r.sha256 != null && sha256.convert(data).toString() != r.sha256) {
        throw _UpdateError('The download was damaged. Please try again.');
      }
    } on _UpdateError catch (e) {
      return _set(UpdateState.ready, problem: e.message);
    } catch (_) {
      return _set(
        UpdateState.ready,
        problem:
            'The update could not be downloaded. Check the internet '
            'connection and try again.',
      );
    }
    _set(UpdateState.installing);
    try {
      await beforeInstall?.call();
    } catch (_) {
      // Unsent changes stay on this device and go up after the update.
    }
    try {
      await installer.launch(data, r.version);
    } catch (_) {
      blocked = true;
      return _set(
        UpdateState.ready,
        problem:
            'Version ${r.version} was downloaded, but Windows or the '
            'antivirus did not let the installer start. You can install it '
            'from the download page instead.',
      );
    }
    // The installer is running: close the database and the app.
    try {
      await beforeQuit?.call();
    } finally {
      installer.quit();
    }
  }

  /// Hides the banner until the next version.
  void later() {
    dismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _first?.cancel();
    _periodic?.cancel();
    _http.close();
    super.dispose();
  }
}

class _UpdateError implements Exception {
  _UpdateError(this.message);
  final String message;
}
