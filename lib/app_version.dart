/// This build's version. It goes up by one with every release, together
/// with `version:` in pubspec.yaml; a release is tagged `v<appVersion>`
/// and the automatic build stops if the two differ.
const appVersion = 15;

/// The GitHub repository whose Releases carry the Windows installer.
const releaseRepo = String.fromEnvironment(
  'AK_RELEASE_REPO',
  defaultValue: 'karimkhatib60-source/ak-system',
);

/// The installer's file name on every release.
const installerAsset = 'AK-System-Setup.exe';
