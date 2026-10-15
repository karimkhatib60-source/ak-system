import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ak_system/app_version.dart';
import 'package:ak_system/update/update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeInstaller implements Installer {
  Uint8List? launched;
  int? version;
  int launches = 0;
  bool quitCalled = false;
  bool fail = false;

  @override
  bool get supported => true;

  @override
  Future<void> launch(Uint8List bytes, int version) async {
    if (fail) throw Exception('blocked by antivirus');
    launches++;
    launched = bytes;
    this.version = version;
  }

  @override
  void quit() => quitCalled = true;
}

void main() {
  final setup = Uint8List.fromList(List.generate(4000, (i) => i % 256));
  final digest = 'sha256:${sha256.convert(setup)}';

  Map<String, Object?> release({
    String tag = 'v11',
    String? assetName,
    int? size,
    String? sha,
    bool prerelease = false,
  }) => {
    'tag_name': tag,
    'draft': false,
    'prerelease': prerelease,
    'body': 'Faster project lists.',
    'assets': [
      {
        'name': 'AK-System-android.apk',
        'browser_download_url': 'https://github.com/x/y/a.apk',
        'size': 10,
      },
      {
        'name': assetName ?? installerAsset,
        'browser_download_url':
            'https://github.com/x/y/releases/download/$tag/$installerAsset',
        'size': size ?? setup.length,
        'digest': ?sha,
      },
    ],
  };

  UpdateService service(
    FakeInstaller installer, {
    Map<String, Object?>? latest,
    int status = 200,
    int repoStatus = 200,
    Uint8List? download,
    Future<void>? downloadGate,
    Future<void>? checkGate,
  }) => UpdateService(
    installer: installer,
    currentVersion: 10,
    repo: 'owner/ak-system',
    client: MockClient((req) async {
      if (req.url.host == 'api.github.com') {
        if (req.url.path == '/repos/owner/ak-system') {
          return http.Response('{}', repoStatus);
        }
        expect(req.url.path, '/repos/owner/ak-system/releases/latest');
        await checkGate;
        return http.Response(jsonEncode(latest ?? release()), status);
      }
      await downloadGate;
      return http.Response.bytes(download ?? setup, 200);
    }),
  );

  test('release tags are read as versions', () {
    expect(versionOfTag('v11'), 11);
    expect(versionOfTag('v12.0.1'), 12);
    expect(versionOfTag('10'), 10);
    expect(versionOfTag('nightly'), isNull);
  });

  test('a release needs the Windows installer', () {
    expect(Release.fromGitHub(release())!.version, 11);
    expect(Release.fromGitHub(release(assetName: 'other.exe')), isNull);
    expect(Release.fromGitHub(release(prerelease: true)), isNull);
    expect(
      Release.fromGitHub(release(sha: digest))!.sha256,
      digest.substring(7),
    );
  });

  test('a newer version is offered, then installed', () async {
    final installer = FakeInstaller();
    final u = service(installer, latest: release(sha: digest));
    final steps = <String>[];
    u.beforeInstall = () async => steps.add('sync');
    u.beforeQuit = () async => steps.add('close');
    await u.check();
    expect(u.state, UpdateState.ready);
    expect(u.available!.version, 11);
    expect(u.available!.notes, 'Faster project lists.');

    await u.install();
    expect(installer.launched, setup);
    expect(installer.version, 11);
    expect(installer.quitCalled, isTrue);
    expect(steps, ['sync', 'close']);
    expect(u.progress, 1);
  });

  test('the same or an older version is not offered', () async {
    for (final tag in ['v10', 'v9']) {
      final u = service(FakeInstaller(), latest: release(tag: tag));
      await u.check();
      expect(u.state, UpdateState.upToDate);
      expect(u.available, isNull);
    }
  });

  test('no release yet is not an error', () async {
    final u = service(FakeInstaller(), latest: {}, status: 404);
    await u.check();
    expect(u.state, UpdateState.upToDate);
  });

  test('an update page that cannot be found is reported', () async {
    final u = service(
      FakeInstaller(),
      latest: {},
      status: 404,
      repoStatus: 404,
    );
    await u.check();
    expect(u.state, UpdateState.failed);
    expect(u.problem, contains('github.com/owner/ak-system'));
    expect(
      u.releasesPage.toString(),
      'https://github.com/owner/ak-system/releases/latest',
    );
  });

  test('a check during a download never interrupts it', () async {
    final installer = FakeInstaller();
    final gate = Completer<void>();
    final u = service(installer, downloadGate: gate.future);
    await u.check();
    final installing = u.install();
    expect(u.state, UpdateState.downloading);
    await u.check(); // the six-hourly check, or "Check now"
    expect(u.state, UpdateState.downloading);
    await u.install(); // a second tap
    gate.complete();
    await installing;
    expect(installer.launches, 1);
  });

  test('"Update now" waits while a check is running', () async {
    final installer = FakeInstaller();
    var gate = Completer<void>()..complete();
    final u = service(installer, checkGate: Future(() => gate.future));
    await u.check();
    expect(u.state, UpdateState.ready);
    gate = Completer<void>();
    final checking = u.check();
    expect(u.state, UpdateState.checking);
    await u.install(); // tapped while the check runs: ignored
    expect(installer.launches, 0);
    gate.complete();
    await checking;
    expect(u.state, UpdateState.ready);
    await u.install();
    expect(installer.launches, 1);
  });

  test('an incomplete or damaged download is never run', () async {
    final short = FakeInstaller();
    final u = service(short, download: Uint8List.fromList([1, 2, 3]));
    await u.check();
    await u.install();
    expect(short.launched, isNull);
    expect(u.state, UpdateState.ready);
    expect(u.problem, contains('incomplete'));

    final damaged = FakeInstaller();
    final bad = Uint8List.fromList(setup.reversed.toList());
    final v = service(
      damaged,
      latest: release(sha: digest),
      download: bad,
    );
    await v.check();
    await v.install();
    expect(damaged.launched, isNull);
    expect(v.problem, contains('damaged'));
  });

  test('if the installer cannot start, the app stays open', () async {
    final installer = FakeInstaller()..fail = true;
    final u = service(installer);
    var closed = false;
    u.beforeQuit = () async => closed = true;
    await u.check();
    await u.install();
    expect(closed, isFalse);
    expect(installer.quitCalled, isFalse);
    expect(u.state, UpdateState.ready);
    expect(u.blocked, isTrue);
    expect(u.problem, contains('antivirus'));
    expect(u.problem, isNot(contains('internet')));
  });

  test('offline: nothing offered, nothing broken', () async {
    final u = UpdateService(
      installer: FakeInstaller(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await u.check();
    expect(u.state, UpdateState.failed);
    expect(u.available, isNull);
  });

  test('"Later" hides the banner until the next version', () async {
    final u = service(FakeInstaller());
    await u.check();
    u.later();
    expect(u.dismissed, isTrue);
    await u.check();
    expect(u.dismissed, isTrue);
  });

  test('this build is version 11, released from the AK repository', () {
    expect(appVersion, 11);
    expect(releaseRepo, 'karimkhatib60-source/ak-system');
  });
}
