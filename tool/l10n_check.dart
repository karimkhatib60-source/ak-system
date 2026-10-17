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
  final call = RegExp(r'\.(tr|td|trArgs|tdArgs|inLang)\b');
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
      final keys = key != null ? [key] : _branchesBefore(src, m.start);
      if (keys.isEmpty) continue;
      final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
      for (final k in keys) {
        out.add((k, '${f.path}:$line'));
      }
    }
  }
  return out;
}

/// The texts of a call on a choice in brackets, `(c ? 'a' : 'b').tr`:
/// each branch that is a literal.
List<String> _branchesBefore(String src, int end) {
  var j = end - 1;
  while (j >= 0 && ' \t\r\n'.contains(src[j])) {
    j--;
  }
  if (j < 0 || src[j] != ')') return const [];
  final close = j;
  // The opening bracket, stepping over strings.
  var depth = 0;
  var open = -1;
  for (var i = close; i >= 0; i--) {
    final c = src[i];
    if (c == "'" || c == '"') {
      final k = _openingQuote(src, i);
      if (k < 0) return const [];
      i = k;
    } else if (c == ')') {
      depth++;
    } else if (c == '(') {
      if (--depth == 0) {
        open = i;
        break;
      }
    }
  }
  if (open < 0) return const [];
  // Branch ends: each ':' outside strings and nested brackets, and the end.
  final ends = <int>[];
  depth = 0;
  for (var i = open + 1; i < close; i++) {
    final c = src[i];
    if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      var k = i + 1;
      while (k < close && (src[k] != c || (!raw && _escaped(src, k)))) {
        k++;
      }
      i = k;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (c == ':' && depth == 0) {
      ends.add(i);
    }
  }
  if (ends.isEmpty) return const [];
  ends.add(close);
  return [for (final e in ends) ?_literalBefore(src, e)];
}

bool _escaped(String src, int k) {
  var slashes = 0;
  for (var b = k - 1; b >= 0 && src[b] == r'\'; b--) {
    slashes++;
  }
  return slashes.isOdd;
}

/// Where the string literal whose closing quote is at [j] opens, or -1.
int _openingQuote(String src, int j) {
  final q = src[j];
  for (var k = j - 1; k >= 0; k--) {
    if (src[k] == q && !_escaped(src, k)) return k;
  }
  return -1;
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
