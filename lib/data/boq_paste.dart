import 'models.dart';

/// Reads BOQ lines pasted from Excel, a message or a document.
///
/// Each line is split on tabs (Excel), or on `|` or `;`. Columns are
/// `[item no.] description, unit, qty, rate [, amount]`; the amount is
/// ignored and worked out again. A line with a single cell (such as
/// "Demolition works" or "2 | Masonry") starts a new section. Header lines ("Description, Unit, ...") are
/// skipped.
List<LineItem> parseBoq(String text) {
  final out = <LineItem>[];
  var section = '';
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final sep = line.contains('\t')
        ? '\t'
        : line.contains('|')
        ? '|'
        : line.contains(';')
        ? ';'
        : null;
    var cells = sep == null
        ? [line]
        : line.split(sep).map((c) => c.trim()).toList();
    // Markdown tables start and end with a bar.
    if (sep == '|') {
      if (cells.first.isEmpty) cells = cells.sublist(1);
      if (cells.isNotEmpty && cells.last.isEmpty) {
        cells = cells.sublist(0, cells.length - 1);
      }
      if (cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) continue;
    }
    while (cells.length > 1 && cells.last.isEmpty) {
      cells.removeLast();
    }
    if (cells.isEmpty) continue;
    if (cells.any((c) => c.toLowerCase() == 'description')) continue;

    // Drop a leading item number such as "3" or "2.1".
    if (cells.length > 1 &&
        RegExp(r'^[A-Za-z]?\d+(\.\d+)*\.?$').hasMatch(cells[0])) {
      cells = cells.sublist(1);
    }

    if (cells.length == 1) {
      section = cells[0].replaceAll(RegExp(r':$'), '').trim();
      continue;
    }

    final description = cells[0];
    var unit = '';
    double? qty;
    double? rate;
    final rest = cells.sublist(1);
    // Unit is the first non-number cell after the description.
    final values = <double>[];
    for (final c in rest) {
      final v = _num(c);
      if (v == null) {
        if (unit.isEmpty) unit = c;
      } else {
        values.add(v);
      }
    }
    if (values.isNotEmpty) qty = values[0];
    if (values.length > 1) rate = values[1];
    out.add(
      LineItem(
        description: description,
        quantity: qty ?? 1,
        unit: unit,
        rate: rate ?? 0,
        section: section,
      ),
    );
  }
  return out;
}

double? _num(String s) {
  final t = s.replaceAll(RegExp(r'[\$,\s]|USD', caseSensitive: false), '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
