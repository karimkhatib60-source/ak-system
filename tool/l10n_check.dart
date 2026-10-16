// Checks the Arabic of the app: every text sent through .tr / .td /
// .trArgs / .tdArgs has its Arabic, with the same {0}, {1}… placeholders.
//
//   dart run tool/l10n_check.dart                 whole app
//   dart run tool/l10n_check.dart lib/ui/x.dart   some files
import 'dart:io';

import 'package:ak_system/l10n/lang.dart';

/// Every English text sent through .tr / .td / .trArgs / .tdArgs, with
/// where it is, read straight from the source.
List<(String key, String where)> translatedTexts([List<String>? files]) {
  final out = <(String, String)>[];
  final call = RegExp(r'\.(tr|td|trArgs|tdArgs)\b');
  final all = files == null
      ? Directory('lib').listSync(recursive: true)
      : [for (final p in files) File(p)];
  for (final f in all) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains(
      '${Platform.pathSeparator}l10n${Platform.pathSeparator}',
    )) {
      continue;
    }
    final src = f.readAsStringSync();
    for (final m in call.allMatches(src)) {
      final key = _literalBefore(src, m.start);
      if (key == null) continue;
      final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
      out.add((key, '${f.path}:$line'));
    }
  }
  return out;
}

/// The (adjacent) string literals ending right before [end], joined, or
/// null when the call is not on a literal.
String? _literalBefore(String src, int end) {
  final parts = <String>[];
  var i = end;
  while (true) {
    var j = i - 1;
    while (j >= 0 && ' \t\r\n'.contains(src[j])) {
      j--;
    }
    if (j < 0 || (src[j] != "'" && src[j] != '"')) break;
    final q = src[j];
    // Find the opening quote, skipping escaped quotes.
    var k = j - 1;
    while (k >= 0) {
      if (src[k] == q) {
        var slashes = 0;
        var b = k - 1;
        while (b >= 0 && src[b] == r'\') {
          slashes++;
          b--;
        }
        if (slashes.isEven) break;
      }
      k--;
    }
    if (k < 0) break;
    var body = src.substring(k + 1, j);
    var raw = false;
    if (k > 0 && src[k - 1] == 'r') raw = true;
    if (!raw) {
      body = body
          .replaceAll(r"\'", "'")
          .replaceAll(r'\"', '"')
          .replaceAll(r'\$', '\u0000')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\\', r'\');
    }
    parts.insert(0, body);
    i = raw ? k - 1 : k;
  }
  if (parts.isEmpty) return null;
  return parts.join();
}

Set<String> holes(String s) =>
    RegExp(r'\{\d+\}').allMatches(s).map((m) => m[0]!).toSet();

/// Problems found, one line each.
List<String> problems([List<String>? files]) => [
  for (final (k, w) in translatedTexts(files))
    if (k.contains(r'$'))
      '$w  has a \$ value; use {0}, {1}… with trArgs: $k'
    else if (!arabicTexts.containsKey(k.replaceAll('\u0000', r'$')))
      '$w  no Arabic: $k',
  for (final e in arabicTexts.entries)
    if (!holes(e.key).containsAll(holes(e.value)) ||
        !holes(e.value).containsAll(holes(e.key)))
      'placeholders differ: ${e.key}',
];

void main(List<String> args) {
  final found = problems(args.isEmpty ? null : args);
  for (final p in found) {
    stdout.writeln(p);
  }
  stdout.writeln(
    '${translatedTexts(args.isEmpty ? null : args).length} texts checked, '
    '${found.length} problems',
  );
  if (found.isNotEmpty) exitCode = 1;
}
