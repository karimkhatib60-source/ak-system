import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/boq_library.dart';
import '../data/company_links.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/project_statement.dart';
import '../data/statement.dart';
import '../data/words.dart';
import 'format.dart';

/// Colours of the document being built, from the chosen report theme.
var _colours = reportThemes.first;
PdfColor get _graphite => PdfColor.fromInt(_colours.ink);
PdfColor get _blue => PdfColor.fromInt(_colours.accent);
PdfColor get _muted => PdfColor.fromInt(_colours.muted);
PdfColor get _line => PdfColor.fromInt(_colours.line);
PdfColor get _soft => PdfColor.fromInt(_colours.soft);

/// Whether the document being built reads right to left (Arabic).
bool get _rtl => docLang == AppLang.ar;

/// Page direction of the document being built.
pw.TextDirection get _dir => _rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

/// Figures sit at the outer end of their column: on the right in English,
/// on the left in Arabic.
pw.TextAlign get _endAlign => _rtl ? pw.TextAlign.left : pw.TextAlign.right;

/// Letter spacing for small capital labels; Arabic letters join, so none.
double _spacing(double v) => _rtl ? 0 : v;

/// Date column width: Arabic month names (تشرين الثاني) need more room.
double get _dateWidth => _rtl ? 88 : 66;

/// Arabic has no capitals, so its small labels are set a point larger.
double _labelSize(double v) => _rtl ? v + 1 : v;

/// The Arabic font, for Arabic typed by the user in an English document.
pw.Font? _arabic;
pw.Font? _arabicBold;

Future<pw.ThemeData> _theme(Repository repo) async {
  _colours = repo.reportTheme;
  Future<ByteData> f(String name) => rootBundle.load('assets/fonts/$name.ttf');
  _arabic = _AdvanceFont(await f('IBMPlexSansArabic-400'));
  _arabicBold = _AdvanceFont(await f('IBMPlexSansArabic-700'));
  // IBM Plex Sans Arabic also has Latin letters and digits.
  if (_rtl) return pw.ThemeData.withFont(base: _arabic, bold: _arabicBold);
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(await f('Manrope-400')),
    bold: pw.Font.ttf(await f('Manrope-700')),
    fontFallback: [_arabic!],
  );
}

/// A font measured by its advance widths. The pdf package places the words
/// of right-to-left lines by their ink width, without side bearings, which
/// leaves uneven gaps in Arabic (a word ending in ر almost touches the next
/// one); measured by advances, words are spaced as the font sets them.
class _AdvanceFont extends pw.TtfFont {
  _AdvanceFont(super.data);

  @override
  PdfFont buildFont(PdfDocument pdfDocument) =>
      _AdvancePdfFont(pdfDocument, data);
}

class _AdvancePdfFont extends PdfTtfFont {
  _AdvancePdfFont(super.pdfDocument, super.bytes);

  @override
  PdfFontMetrics stringMetrics(String s, {double letterSpacing = 0}) {
    final m = super.stringMetrics(s, letterSpacing: letterSpacing);
    return PdfFontMetrics(
      left: 0,
      top: m.top,
      right: m.advanceWidth,
      bottom: m.bottom,
      ascent: m.ascent,
      descent: m.descent,
      advanceWidth: m.advanceWidth,
      leftBearing: 0,
    );
  }
}

final _arabicLetters = RegExp(
  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

/// Latin letters, which read left to right inside Arabic text.
final _latinLetters = RegExp(r'[A-Za-z\u00C0-\u024F]');

/// Text in the document's direction. Text that reads the other way (Latin
/// in an Arabic document, Arabic typed by the user in an English one) keeps
/// its own direction, so its words and lines stay in order, and Arabic is
/// set in the Arabic font. Its lines start on the document's side unless
/// [align] says otherwise.
pw.Widget _text(String s, {pw.TextStyle? style, pw.TextAlign? align}) {
  final arabic = _arabicLetters.hasMatch(s);
  final own = arabic == _rtl;
  if (!own && arabic) {
    style = (style ?? const pw.TextStyle()).copyWith(
      fontNormal: _arabic,
      fontBold: _arabicBold,
    );
  }
  if (!own) align ??= _rtl ? pw.TextAlign.right : pw.TextAlign.left;
  // A short line of Arabic with Latin words in it, such as a statement line
  // naming an invoice; long texts may run over pages, which [_MixedLines]
  // cannot, and keep the pdf package's own line breaking.
  if (arabic &&
      _latinLetters.hasMatch(s) &&
      !s.contains('\n') &&
      s.length <= 240) {
    return _MixedLines(s, style, align ?? pw.TextAlign.start);
  }
  if (own) return pw.Text(s, style: style, textAlign: align);
  return pw.Text(
    s,
    style: style,
    textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    textAlign: align,
  );
}

/// Arabic letters proper, which set the direction of the text around them
/// (Arabic punctuation, digits and vowel marks do not).
final _arabicStrong = RegExp(
  r'[\u0620-\u064A\u066E-\u06D3\u06FA-\u06FF\u0750-\u077F\uFB50-\uFDFF'
  r'\uFE70-\uFEFF]',
);

/// Text with both Arabic and Latin words in it, set right to left (the pdf
/// package shapes Arabic only so). The package puts the words of a paragraph
/// in display order before breaking it into lines, so a phrase in the other
/// direction cut by a line break has its words on the wrong lines (the end
/// of the phrase on the first line, its start on the next), and it has no
/// rule pairing brackets, so "(Villa Byblos)" before Arabic loses its
/// closing bracket to the far side. Here the text is broken into lines in
/// reading order first, and each line is set as spans, one for each run of
/// words in one direction, which the package lays out from right to left.
class _MixedLines extends pw.Widget {
  _MixedLines(this.text, this.style, this.align);

  final String text;
  final pw.TextStyle? style;
  final pw.TextAlign align;
  pw.Widget? _child;

  pw.Text _line(String s) => pw.Text(
    s,
    style: style,
    textAlign: align,
    textDirection: pw.TextDirection.rtl,
  );

  double _width(pw.Context context, String s) =>
      (_line(s)..layout(context, const pw.BoxConstraints())).box!.width;

  /// Whether the first letter that sets a direction in [s] is Latin.
  static bool _latinFirst(String s) {
    final a = s.indexOf(_arabicStrong), l = s.indexOf(_latinLetters);
    return l >= 0 && (a < 0 || l < a);
  }

  /// Punctuation ending a run of words in the other direction: it belongs
  /// to the text around the run, so it is set after the run, not inside it.
  static final _tail = RegExp(r'[\u060C\u061B\u061F.,:;!?]+$');

  /// One line of the text, its words given with the run each belongs to
  /// (null outside a run) and where the punctuation ending a run starts.
  pw.Widget _setLine(
    List<String> words,
    List<int?> runs,
    Map<int, int> tails,
    int from,
    int to,
    bool rtl,
  ) {
    final spans = <pw.InlineSpan>[];
    void add(String s) => spans.add(pw.TextSpan(text: s));
    var i = from;
    while (i < to) {
      var end = i;
      while (end + 1 < to && runs[end + 1] == runs[i]) {
        end++;
      }
      if (spans.isNotEmpty) add(' ');
      final part = words.sublist(i, end + 1);
      final cut = runs[i] == null ? null : tails[end];
      if (cut != null) {
        part.last = part.last.substring(0, cut);
        add(part.join(' '));
        final rest = words[end].substring(cut);
        add(rtl ? _rtlSigns(rest) : rest);
      } else if (rtl && runs[i] == null && !part.any(_arabicStrong.hasMatch)) {
        // Figures and signs alone would be read left to right: put them in
        // right-to-left order by hand.
        add(part.reversed.map(_rtlSigns).join(' '));
      } else {
        add(part.join(' '));
      }
      i = end + 1;
    }
    return pw.RichText(
      // The spans go from right to left; in a left-to-right text, in reverse.
      text: pw.TextSpan(
        style: style,
        children: rtl ? spans : spans.reversed.toList(),
      ),
      textAlign: align,
      textDirection: pw.TextDirection.rtl,
    );
  }

  /// Figures and signs as they show in right-to-left text: the figures read
  /// left to right, the signs around them ($, %) in reverse, brackets
  /// mirrored, as the pdf package sets them after Arabic words.
  static String _rtlSigns(String w) {
    const mirror = {'(': ')', ')': '(', '[': ']', ']': '['};
    return [
      for (final m in RegExp(r'[0-9]+(?:[.,][0-9]+)*|.').allMatches(w))
        mirror[m[0]] ?? m[0]!,
    ].reversed.join();
  }

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final words = text.split(' ');
    final rtl = !_latinFirst(text);
    // 1: a word in the other direction, 2: one in the text's direction,
    // 3: figures (they join a run they follow), 0: signs.
    final kind = [
      for (final w in words)
        if (_arabicStrong.hasMatch(w))
          rtl ? 2 : 1
        else if (_latinLetters.hasMatch(w))
          rtl ? 1 : 2
        else if (w.contains(RegExp('[0-9]')))
          3
        else
          0,
    ];
    // Runs in the other direction, with the figures and signs between their
    // words, and the punctuation that ends each.
    final runs = List<int?>.filled(words.length, null);
    final tails = <int, int>{};
    for (var i = 0; i < words.length; i++) {
      if (kind[i] != 1) continue;
      var end = i;
      for (var k = i; k < words.length && kind[k] != 2; k++) {
        if (kind[k] == 1 || kind[k] == 3) end = k;
      }
      for (var k = i; k <= end; k++) {
        runs[k] = i;
      }
      final t = _tail.firstMatch(words[end]);
      if (t != null && t.start > 0) tails[end] = t.start;
      i = end;
    }
    // Lines broken in reading order.
    final max = constraints.maxWidth + 0.00001;
    final breaks = <int>[0];
    if (constraints.hasBoundedWidth && _width(context, text) > max) {
      for (var k = 1; k < words.length; k++) {
        final line = words.sublist(breaks.last, k + 1).join(' ');
        if (_width(context, line) > max) breaks.add(k);
      }
    }
    breaks.add(words.length);
    // A "·" between parts is dropped where a line breaks next to it.
    final lines = <pw.Widget>[];
    for (var n = 0; n + 1 < breaks.length; n++) {
      var from = breaks[n], to = breaks[n + 1];
      while (to > from + 1 && words[to - 1] == '·') {
        to--;
      }
      while (from + 1 < to && words[from] == '·') {
        from++;
      }
      lines.add(_setLine(words, runs, tails, from, to, rtl));
    }
    _child = lines.length == 1
        ? lines.single
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: lines,
          );
    _child!.layout(context, constraints, parentUsesSize: parentUsesSize);
    box = _child!.box;
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    // The child is drawn where its parent placed this widget.
    _child!
      ..box = box
      ..paint(context);
  }
}

/// Table cells in reading order: in Arabic the first column is on the right.
List<T> _cols<T>(List<T> cells) => _rtl ? cells.reversed.toList() : cells;

/// Column widths matching [_cols].
Map<int, pw.TableColumnWidth> _colWidths(
  Map<int, pw.TableColumnWidth> widths,
  int count,
) => _rtl
    ? {for (final e in widths.entries) count - 1 - e.key: e.value}
    : widths;

/// Builds the branded PDF for a quotation or an invoice.
Future<Uint8List> buildPdf(Repository repo, PricedDocument doc) async {
  final isInvoice = doc is Invoice;
  final number = isInvoice ? doc.number : (doc as Quotation).number;
  final title = isInvoice ? doc.title : (doc as Quotation).title;
  final clientId = isInvoice ? doc.clientId : (doc as Quotation).clientId;
  final projectId = isInvoice ? doc.projectId : (doc as Quotation).projectId;
  final date = isInvoice ? doc.date : (doc as Quotation).date;
  final second = isInvoice ? doc.dueDate : (doc as Quotation).validUntil;
  final notes = isInvoice ? doc.notes : (doc as Quotation).notes;
  final terms = isInvoice
      ? repo.companyText('terms', docLang)
      : (doc as Quotation).terms.td;
  final client = repo.client(clientId);
  final project = repo.project(projectId);
  final info = repo.companyInfo;
  final paid = isInvoice ? repo.paidOn(doc) : 0.0;
  final setOff = isInvoice ? repo.advanceOn(doc) : 0.0;

  final pdf = pw.Document(
    theme: await _theme(repo),
    title: '$number ${isInvoice ? 'Invoice'.td : 'Quotation'.td}',
    author: repo.companyName,
  );

  const label = _label;

  pw.Widget moneyRow(String l, double v, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: _text(
            l,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 9.5,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
        ),
        _text(
          fmtMoney(v),
          style: pw.TextStyle(
            fontSize: bold ? 11 : 9.5,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    ),
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      textDirection: _dir,
      header: (ctx) =>
          _header(repo, isInvoice ? 'INVOICE'.td : 'QUOTATION'.td, number),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        // Parties and dates.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label(isInvoice ? 'Bill to'.td : 'Prepared for'.td),
                  pw.SizedBox(height: 3),
                  _text(
                    client?.name ?? '—',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (client != null && client.company.isNotEmpty)
                    _text(
                      client.company,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (client != null)
                    _text(
                      [
                        client.phone,
                        client.email,
                        client.country.td,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Container(
              width: 190,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv('Date'.td, fmtDocDate(date)),
                  if (second != null)
                    _kv(
                      isInvoice ? 'Payment due'.td : 'Valid until'.td,
                      fmtDocDate(second),
                    ),
                  if (project != null) _kv('Project'.td, project.code),
                  if (info['tax_number']?.isNotEmpty ?? false)
                    _kv('VAT no.'.td, info['tax_number']!),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        if (title.isNotEmpty || project != null) ...[
          label('Subject'.td),
          pw.SizedBox(height: 3),
          _text(
            title.isNotEmpty ? title : project!.name,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          if (project != null && project.location.isNotEmpty)
            _text(
              '${project.name} · ${project.location}',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          pw.SizedBox(height: 14),
        ],
        // Items.
        _itemsTable(doc),
        pw.SizedBox(height: 10),
        // Totals.
        pw.Row(
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  if (doc.showMarkup && doc.markupRate != 0) ...[
                    moneyRow('Cost subtotal'.td, doc.subtotal),
                    moneyRow(
                      'Cost-plus fee {0}%'.tdArgs([_qty(doc.markupRate)]),
                      doc.markup,
                    ),
                  ] else
                    moneyRow('Subtotal'.td, doc.subtotal + doc.markup),
                  if (doc.discount != 0) moneyRow('Discount'.td, -doc.discount),
                  moneyRow('VAT {0}%'.tdArgs([_qty(doc.vatRate)]), doc.vat),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    height: 1,
                    color: _graphite,
                  ),
                  moneyRow('Total (USD)'.td, doc.total, bold: true),
                  if (isInvoice && paid > 0) ...[
                    if (paid - setOff > 0.005)
                      moneyRow('Received'.td, -(paid - setOff)),
                    if (setOff > 0.005)
                      moneyRow('Set off from other payments'.td, -setOff),
                    moneyRow('Balance due'.td, repo.balanceOf(doc), bold: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        if (!isInvoice && (doc as Quotation).paymentTerms.isNotEmpty) ...[
          label('Payment schedule'.td),
          pw.SizedBox(height: 5),
          _scheduleTable(doc),
          pw.SizedBox(height: 16),
        ],
        if (notes.isNotEmpty) ...[
          label('Notes'.td),
          pw.SizedBox(height: 3),
          _text(notes, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        if (isInvoice && (info['bank']?.isNotEmpty ?? false)) ...[
          label('Payment details'.td),
          pw.SizedBox(height: 3),
          _text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        if (terms.isNotEmpty) ...[
          label('Terms and conditions'.td),
          pw.SizedBox(height: 3),
          _text(terms, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
        ],
        if (!isInvoice) ...[
          pw.SizedBox(height: 36),
          pw.Row(
            children: [
              pw.Expanded(
                child: _signature('For {0}'.tdArgs([repo.companyName])),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(child: _signature('Client acceptance'.td)),
            ],
          ),
        ],
      ],
    ),
  );
  return pdf.save();
}

/// A quotation's payment terms: instalment, when due, share and amount.
pw.Widget _scheduleTable(Quotation q) {
  final terms = q.paymentTerms;
  final rows = [
    for (final (k, t) in terms.indexed)
      [
        '${k + 1}',
        t.label.isEmpty ? 'Payment {0}'.tdArgs([k + 1]) : t.label.td,
        t.due.td,
        t.percent == 0 ? '' : '${_qty(t.percent)}%',
        fmtMoney(t.valueOf(q.total)),
      ],
  ];
  final pct = terms.fold(0.0, (s, t) => s + t.percent);
  final sum = terms.fold(0.0, (s, t) => s + t.valueOf(q.total));
  rows.add([
    '',
    'Total'.td,
    '',
    pct == 0 ? '' : '${_qty(pct)}%',
    fmtMoney(sum),
  ]);
  return _table(
    ['#', 'Instalment'.td, 'Due'.td, 'Share'.td, 'Amount'.td],
    rows,
    widths: {
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(3.4),
      3: const pw.FixedColumnWidth(44),
      4: const pw.FixedColumnWidth(72),
    },
    right: {3, 4},
    boldRows: {rows.length - 1},
    softRows: {rows.length - 1},
  );
}

pw.Widget _kv(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 70,
        child: _text(k, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
      ),
      pw.Expanded(
        child: _text(
          v,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  ),
);

pw.Widget _signature(String who) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.SizedBox(height: 30),
    pw.Container(height: .8, color: _graphite),
    pw.SizedBox(height: 4),
    _text(who, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
    _text(
      'Name, signature and date'.td,
      style: pw.TextStyle(fontSize: 7.5, color: _muted),
    ),
  ],
);

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Opens the system share sheet (or downloads, in a browser) with the PDF.
Future<void> sharePdf(Repository repo, PricedDocument doc) async {
  final bytes = await buildPdf(repo, doc);
  final number = doc is Invoice ? doc.number : (doc as Quotation).number;
  await Printing.sharePdf(bytes: bytes, filename: '$number.pdf');
}

/// The priced lines, grouped under their sections with a subtotal after
/// each. When the cost-plus fee is not shown, it is spread into the rates
/// so the lines add up to the same total.
pw.Widget _itemsTable(PricedDocument doc) {
  final factor = doc.showMarkup ? 1.0 : 1 + doc.markupRate / 100;
  final sectioned = doc.items.any((i) => i.section.isNotEmpty);
  const cell = pw.TextStyle(fontSize: 9);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  final head = pw.TextStyle(
    color: PdfColors.white,
    fontWeight: pw.FontWeight.bold,
    fontSize: 8.5,
  );
  const pad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6);
  const rightCols = {2, 4, 5};

  pw.Widget c(String t, int col, pw.TextStyle style) => pw.Padding(
    padding: pad,
    child: _text(
      t,
      style: style,
      align: rightCols.contains(col) ? _endAlign : null,
    ),
  );
  pw.TableRow row(
    List<String> cells, {
    pw.TextStyle style = cell,
    PdfColor? fill,
  }) => pw.TableRow(
    decoration: pw.BoxDecoration(
      color: fill,
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6)),
    ),
    children: _cols([for (var k = 0; k < 6; k++) c(cells[k], k, style)]),
  );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: pw.BoxDecoration(color: _graphite),
      children: _cols([
        for (final (k, h) in [
          '#',
          'Description'.td,
          'Qty'.td,
          'Unit'.td,
          'Rate'.td,
          'Amount'.td,
        ].indexed)
          c(h, k, head),
      ]),
    ),
  ];

  // Keep the order items were entered, gathering each section together.
  final groups = <String, List<LineItem>>{};
  for (final i in doc.items) {
    (groups[i.section] ??= []).add(i);
  }
  // Library trades print in BOQ order; other sections follow as entered.
  int rank(String name) {
    final i = boqSections.indexOf(name);
    return i < 0 ? 1000 : i;
  }

  final keys = groups.keys.toList();
  final ordered = groups.entries.toList()
    ..sort((a, b) {
      final r = rank(a.key).compareTo(rank(b.key));
      return r != 0 ? r : keys.indexOf(a.key).compareTo(keys.indexOf(b.key));
    });
  var g = 0;
  var n = 0;
  for (final MapEntry(key: name, value: items) in ordered) {
    g++;
    final showHead = sectioned;
    if (showHead) {
      rows.add(
        row(
          [
            '$g',
            name.isEmpty ? 'General'.td : name.td.toUpperCase(),
            '',
            '',
            '',
            '',
          ],
          style: bold,
          fill: _soft,
        ),
      );
    }
    var sum = 0.0;
    for (var k = 0; k < items.length; k++) {
      final i = items[k];
      n++;
      final amount = i.amount * factor;
      sum += amount;
      rows.add(
        row([
          sectioned ? '$g.${k + 1}' : '$n',
          i.description.td,
          _qty(i.quantity),
          i.unit.td,
          fmtMoney(i.rate * factor),
          fmtMoney(amount),
        ]),
      );
    }
    if (showHead && groups.length > 1) {
      rows.add(
        row([
          '',
          'Total {0}'.tdArgs([name.isEmpty ? 'general'.td : name.td]),
          '',
          '',
          '',
          fmtMoney(sum),
        ], style: bold),
      );
    }
  }

  return pw.Table(
    columnWidths: _colWidths({
      0: const pw.FixedColumnWidth(26),
      1: const pw.FlexColumnWidth(5),
      2: const pw.FixedColumnWidth(36),
      3: const pw.FixedColumnWidth(50),
      4: const pw.FixedColumnWidth(68),
      5: const pw.FixedColumnWidth(76),
    }, 6),
    children: rows,
  );
}

pw.Widget _header(Repository repo, String title, String number) => pw.Column(
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (repo.companyLogo != null)
          pw.ConstrainedBox(
            constraints: const pw.BoxConstraints(maxWidth: 120, maxHeight: 44),
            child: pw.Image(
              pw.MemoryImage(repo.companyLogo!),
              fit: pw.BoxFit.contain,
            ),
          )
        else
          pw.Container(
            width: 34,
            height: 34,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _blue,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              'AK',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(
                repo.companyName,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: _graphite,
                ),
              ),
              _text(
                'Design · Consultancy · Contracting'.td,
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _graphite,
                letterSpacing: _spacing(2),
              ),
            ),
            _text(number, style: pw.TextStyle(fontSize: 10, color: _blue)),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 10),
    pw.Container(height: 2, color: _graphite),
    pw.SizedBox(height: 16),
  ],
);

pw.Widget _footer(pw.Context ctx, Repository repo) {
  final links = companyLinks(repo.companyInfo);
  final address = repo.companyText('address', docLang);
  final style = pw.TextStyle(fontSize: 7.5, color: _muted);
  return pw.Column(
    children: [
      pw.Container(height: 0.6, color: _line),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                if (address.isNotEmpty)
                  _text(address.split('\n').first, style: style),
                for (final l in links)
                  pw.UrlLink(
                    destination: l.url,
                    child: _text(
                      '${_linkLabel(l.kind)}${l.display}',
                      style: style,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          _text(
            'Page {0} of {1}'.tdArgs([ctx.pageNumber, ctx.pagesCount]),
            style: style,
          ),
        ],
      ),
    ],
  );
}

String _linkLabel(String kind) => kind == 'instagram' ? 'Instagram ' : '';

/// [s] with only the characters file names can hold, Arabic included.
String _fileSafe(String s) => s
    .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-')
    .replaceAll(RegExp(r'-+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Builds the branded statement of account for a client.
Future<Uint8List> buildStatementPdf(Repository repo, Statement built) async {
  // The lines are worded again when built in another language.
  final st = built.lang == docLang
      ? built
      : buildStatement(
          repo,
          built.client.id,
          from: built.from,
          to: built.to,
          projectId: built.projectId,
          lang: docLang,
        );
  final info = repo.companyInfo;
  final client = st.client;
  final pdf = pw.Document(
    theme: await _theme(repo),
    title: 'Statement of account {0}'.tdArgs([client.name]),
    author: repo.companyName,
  );
  const label = _label;
  const table = _table;
  String m(double v) => v == 0 ? '' : fmtMoney(v);
  pw.Widget tile(String l, double v, {bool strong = false}) =>
      _tile(l, fmtMoney(v), strong: strong);

  final moves = <List<String>>[
    if (st.from != null)
      [
        fmtDocDate(st.from),
        '',
        'Opening balance'.td,
        '',
        '',
        fmtMoney(st.opening),
      ],
    for (final l in st.lines)
      [
        fmtDocDate(l.date),
        l.reference,
        l.description,
        m(l.debit),
        m(l.credit),
        fmtMoney(l.balance),
      ],
    [
      fmtDocDate(st.to),
      '',
      'Closing balance'.td,
      fmtMoney(st.invoiced),
      fmtMoney(st.received),
      fmtMoney(st.closing),
    ],
  ];
  final aging = st.aging;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      textDirection: _dir,
      header: (ctx) => _header(
        repo,
        'STATEMENT'.td,
        'As of {0}'.tdArgs([fmtDocDate(st.to)]),
      ),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('Statement of account for'.td),
                  pw.SizedBox(height: 3),
                  _text(
                    client.name,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (client.company.isNotEmpty)
                    _text(
                      client.company,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  _text(
                    [
                      client.phone,
                      client.email,
                      client.country.td,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Container(
              width: _rtl ? 230 : 200,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv(
                    'Period'.td,
                    st.from == null
                        ? 'All to {0}'.tdArgs([fmtDocDate(st.to)])
                        : '${fmtDocDate(st.from)} – ${fmtDocDate(st.to)}',
                  ),
                  _kv(
                    'Project'.td,
                    st.project == null
                        ? 'All projects'.td
                        : '${st.project!.code} ${st.project!.name}',
                  ),
                  _kv('Currency'.td, 'USD'),
                  if (info['tax_number']?.isNotEmpty ?? false)
                    _kv('VAT no.'.td, info['tax_number']!),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            if (st.contractValue > 0)
              tile('Agreed contract'.td, st.contractValue),
            if (st.from != null) tile('Opening balance'.td, st.opening),
            tile('Invoiced'.td, st.invoiced),
            tile('Received'.td, st.received),
            if (st.advances > 0.005) ...[
              tile('Credit held'.td, st.advances),
              tile('Due on invoices'.td, st.dueOnInvoices, strong: true),
            ] else if (st.closing < -0.005)
              tile('Credit balance'.td, -st.closing, strong: true)
            else
              tile('Balance due'.td, st.closing, strong: true),
          ],
        ),
        pw.SizedBox(height: 16),
        label('Account movements'.td),
        pw.SizedBox(height: 5),
        table(
          [
            'Date'.td,
            'Reference'.td,
            'Description'.td,
            'Debit'.td,
            'Credit@@column'.td,
            'Balance'.td,
          ],
          moves,
          widths: {
            0: pw.FixedColumnWidth(_dateWidth),
            1: const pw.FixedColumnWidth(64),
            2: const pw.FlexColumnWidth(4),
            3: const pw.FixedColumnWidth(62),
            4: const pw.FixedColumnWidth(62),
            5: const pw.FixedColumnWidth(66),
          },
          right: {3, 4, 5},
          boldRows: {if (st.from != null) 0, moves.length - 1},
          softRows: {moves.length - 1},
        ),
        if (st.open.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          label('Open invoices'.td),
          pw.SizedBox(height: 5),
          table(
            [
              'Invoice'.td,
              'Date'.td,
              'Due'.td,
              'Amount'.td,
              'Paid@@column'.td,
              'Balance'.td,
              'Late@@column'.td,
            ],
            [
              for (final o in st.open)
                [
                  o.invoice.number,
                  fmtDocDate(o.invoice.date),
                  fmtDocDate(o.invoice.dueDate),
                  fmtMoney(o.invoice.total),
                  fmtMoney(o.paid),
                  fmtMoney(o.balance),
                  o.daysOverdue > 0
                      ? '{0} days@@late'.tdArgs([o.daysOverdue])
                      : 'Not due'.td,
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(2),
              1: pw.FixedColumnWidth(_dateWidth),
              2: pw.FixedColumnWidth(_dateWidth),
              3: const pw.FixedColumnWidth(62),
              4: const pw.FixedColumnWidth(62),
              5: const pw.FixedColumnWidth(62),
              6: const pw.FixedColumnWidth(52),
            },
            right: {3, 4, 5, 6},
          ),
          pw.SizedBox(height: 10),
          table(
            [
              'Not yet due'.td,
              '1–30 days'.td,
              '31–60 days'.td,
              '61–90 days'.td,
              '90+ days'.td,
            ],
            [
              [for (final v in aging) fmtMoney(v)],
            ],
            widths: {for (var k = 0; k < 5; k++) k: const pw.FlexColumnWidth()},
            right: {0, 1, 2, 3, 4},
          ),
        ],
        pw.SizedBox(height: 18),
        if (info['bank']?.isNotEmpty ?? false) ...[
          label('Bank details'.td),
          pw.SizedBox(height: 3),
          _text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        if (st.advances > 0.005)
          _text(
            'Credit held: {0} received and not yet set against an '
                    'invoice. Every payment received, as an advance, on '
                    'account or on an invoice, settles the issued invoices of '
                    'the same project oldest first; the rest is set against '
                    'the next invoices. Due on issued invoices: {1}. Net '
                    'account balance: {2}. Please report any difference '
                    'within 15 days of this statement; otherwise it is '
                    'considered accepted.'
                .tdArgs([
                  fmtMoney(st.advances),
                  fmtMoney(st.dueOnInvoices),
                  _net(st.closing),
                ]),
            style: pw.TextStyle(fontSize: 8.5, color: _muted),
          )
        else
          _text(
            st.closing > 0.005
                ? 'Kindly settle the balance due of {0}. '
                          'Please report any difference within 15 days of this '
                          'statement; otherwise it is considered accepted.'
                      .tdArgs([fmtMoney(st.closing)])
                : st.closing < -0.005
                ? 'Your account is in credit by {0}. '
                          'Please report any difference within 15 days of this '
                          'statement; otherwise it is considered accepted.'
                      .tdArgs([fmtMoney(-st.closing)])
                : 'Your account is fully settled. Thank you.'.td,
            style: pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        pw.SizedBox(height: 30),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(height: .6, color: _graphite),
                  pw.SizedBox(height: 4),
                  _text(
                    'For {0}'.tdArgs([repo.companyName]),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 60),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(height: .6, color: _graphite),
                  pw.SizedBox(height: 4),
                  _text(
                    'Client confirmation'.td,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return pdf.save();
}

Future<void> shareStatementPdf(Repository repo, Statement st) async {
  final bytes = await buildStatementPdf(repo, st);
  final name = _fileSafe(st.client.name);
  await Printing.sharePdf(
    bytes: bytes,
    filename:
        '${_fileSafe('Statement@@file'.td)}-$name-'
        '${st.to.toIso8601String().substring(0, 10)}.pdf',
  );
}

/// "Net account balance" on statements: the amount, or "credit" and the
/// amount when the client is in credit.
String _net(double closing) => closing < 0
    ? 'credit {0}'.tdArgs([fmtMoney(closing.abs())])
    : fmtMoney(closing.abs());

pw.Widget _label(String s) => _text(
  s.toUpperCase(),
  style: pw.TextStyle(
    fontSize: _labelSize(7.5),
    color: _muted,
    letterSpacing: _spacing(1),
  ),
);

/// A data table with a graphite header row, as used on statements.
pw.Widget _table(
  List<String> headers,
  List<List<String>> rows, {
  required Map<int, pw.TableColumnWidth> widths,
  required Set<int> right,
  Set<int> boldRows = const {},
  Set<int> softRows = const {},
}) {
  const cell = pw.TextStyle(fontSize: 8.5);
  final bold = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  final head = pw.TextStyle(
    color: PdfColors.white,
    fontWeight: pw.FontWeight.bold,
    fontSize: 8,
  );
  const pad = pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5);
  pw.Widget c(String t, int k, pw.TextStyle style) => pw.Padding(
    padding: pad,
    child: _text(t, style: style, align: right.contains(k) ? _endAlign : null),
  );
  return pw.Table(
    columnWidths: _colWidths(widths, headers.length),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: _graphite),
        children: _cols([for (final (k, h) in headers.indexed) c(h, k, head)]),
      ),
      for (final (r, row) in rows.indexed)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: softRows.contains(r) ? _soft : null,
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6)),
          ),
          children: _cols([
            for (final (k, t) in row.indexed)
              c(t, k, boldRows.contains(r) ? bold : cell),
          ]),
        ),
    ],
  );
}

/// A summary figure box; [strong] is the dark one for the key figure.
pw.Widget _tile(String l, String value, {bool strong = false}) => pw.Expanded(
  child: pw.Container(
    margin: const pw.EdgeInsetsDirectional.only(end: 6),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: strong ? _graphite : _soft,
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          l.toUpperCase(),
          style: pw.TextStyle(
            fontSize: _labelSize(6.5),
            letterSpacing: _spacing(.8),
            color: strong ? PdfColors.white : _muted,
          ),
        ),
        pw.SizedBox(height: 3),
        _text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: strong ? PdfColors.white : _graphite,
          ),
        ),
      ],
    ),
  ),
);

/// Two signature lines: the company first (on the left in English, on the
/// right in Arabic), then [other].
pw.Widget _signatures(Repository repo, String other) {
  pw.Widget line(String t) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: .6, color: _graphite),
        pw.SizedBox(height: 4),
        _text(t, style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
  return pw.Row(
    children: [
      line('For {0}'.tdArgs([repo.companyName])),
      pw.SizedBox(width: 60),
      line(other),
    ],
  );
}

/// The "prepared for" client block with a facts box at the end (on the
/// right in English, on the left in Arabic).
pw.Widget _partyBlock(String caption, Client? client, List<pw.Widget> facts) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label(caption),
              pw.SizedBox(height: 3),
              _text(
                client?.name ?? '—',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (client != null && client.company.isNotEmpty)
                _text(client.company, style: const pw.TextStyle(fontSize: 9)),
              if (client != null)
                _text(
                  [
                    client.phone,
                    client.email,
                    client.country.td,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 210,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _soft,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: facts,
          ),
        ),
      ],
    );

String _pct(double v) => '${v.toStringAsFixed(v >= 10 || v == 0 ? 0 : 1)}%';

/// Builds the receipt for one payment received: on an invoice, on a
/// payment term of a quotation, or on account.
/// [first], then where a receipt went as of its [day]: the part that
/// settled older invoices (other than those [own] picks) and the part
/// still held as credit. [kept] is the part counted on the receipt's own
/// instalment.
String _usedText(
  Repository repo,
  Payment pay,
  DateTime day,
  String first,
  bool Function(Invoice) own, {
  double? kept,
}) {
  final elsewhere = [
    for (final (i, a) in repo.appliedTo(pay, until: day, through: pay))
      if (!own(i)) (i, a),
  ];
  final went = elsewhere.fold(0.0, (s, e) => s + e.$2);
  // Credit beyond what stayed on the receipt's own invoice or instalment.
  final held = kept != null
      ? pay.amount - kept - went
      : repo.unappliedOf(pay, until: day, through: pay);
  return [
    first,
    if (went > 0.005)
      'Open invoices are settled oldest first, so {0} of '
              'this receipt went to {1}.'
          .tdArgs([
            fmtMoney(went),
            elsewhere.map((e) => e.$1.number).join(', '),
          ]),
    if (held > 0.005)
      'The extra {0} is held as credit on the account.'.tdArgs([
        fmtMoney(held),
      ]),
  ].join(' ');
}

Future<Uint8List> buildReceiptPdf(Repository repo, Payment pay) async {
  final inv = repo.invoice(pay.invoiceId);
  final q = inv == null ? repo.quotation(pay.quotationId) : null;
  final termIndex = pay.termIndex;
  final term =
      q != null && termIndex != null && termIndex < q.paymentTerms.length
      ? q.paymentTerms[termIndex]
      : null;
  final client = repo.client(repo.payerOf(pay));
  final project = repo.project(repo.projectOfPayment(pay));
  final pdf = pw.Document(
    theme: await _theme(repo),
    title: '${pay.number} ${'Receipt'.td}',
    author: repo.companyName,
  );

  // What the money was for, and where that stands after this receipt.
  final String purpose;
  final pw.Widget detail;
  final String after;
  if (inv != null && inv.status != InvoiceStatus.sent) {
    // A draft or cancelled invoice takes no money: the receipt went to the
    // open invoices like money on account.
    purpose = 'Invoice {0}'.tdArgs([inv.number]);
    detail = _table(
      ['Description'.td, 'Amount'.td],
      [
        [
          inv.title.isNotEmpty ? '${inv.number} · ${inv.title}' : inv.number,
          fmtMoney(pay.amount),
        ],
      ],
      widths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FixedColumnWidth(80),
      },
      right: {1},
    );
    after = _usedText(
      repo,
      pay,
      pay.date,
      inv.status == InvoiceStatus.cancelled
          ? '{0} is cancelled, so this receipt is set against the open '
                    'invoices, oldest first.'
                .tdArgs([inv.number])
          : '{0} is not issued yet, so this receipt is set against the '
                    'open invoices, oldest first.'
                .tdArgs([inv.number]),
      (i) => false,
    );
  } else if (inv != null) {
    // Every receipt goes to the client's open invoices oldest first, so
    // part of this one may have settled older invoices on its day. An
    // invoice dated after the receipt counts from its own date.
    final cut = inv.date.isAfter(pay.date) ? inv.date : pay.date;
    var prior = 0.0, here = 0.0;
    for (final (o, a) in repo.settledBy(inv, until: cut, through: pay)) {
      if (o.id == pay.id) {
        here += a;
      } else {
        prior += a;
      }
    }
    final total = (inv.total * 100).round() / 100;
    final rest = total - prior - here;
    final left = rest > 0 ? rest : 0.0;
    purpose = 'Invoice {0}'.tdArgs([inv.number]);
    detail = _table(
      [
        'Invoice'.td,
        'Subject'.td,
        'Invoice total'.td,
        'Received before'.td,
        'This receipt'.td,
        'Balance'.td,
      ],
      [
        [
          inv.number,
          inv.title.isNotEmpty ? inv.title : (project?.name ?? ''),
          fmtMoney(inv.total),
          fmtMoney(prior),
          fmtMoney(here),
          fmtMoney(left.abs() < .005 ? 0 : left),
        ],
      ],
      widths: _receiptWidths,
      right: {2, 3, 4, 5},
    );
    after = _usedText(
      repo,
      pay,
      cut,
      left <= 0.005
          ? '{0} is now fully paid. Thank you.'.tdArgs([inv.number])
          : 'Remaining on {0}: {1}.'.tdArgs([inv.number, fmtMoney(left)]),
      (i) => i.id == inv.id,
    );
  } else if (q != null && term != null) {
    final value = (term.valueOf(q.total) * 100).round() / 100;
    // Where the instalment stood just before this receipt and with it, as
    // of its day. Part of the money may have settled older invoices first.
    final was = repo
        .termStatus(q, termIndex!, until: pay.date, through: pay, before: true)
        .received;
    final now = repo
        .termStatus(q, termIndex, until: pay.date, through: pay)
        .received;
    final change = now - was;
    final here = change < 0 ? 0.0 : (change > pay.amount ? pay.amount : change);
    final rest = value - now;
    final left = rest > 0 ? rest : 0.0;
    final label = term.label.isEmpty
        ? 'Payment {0}'.tdArgs([termIndex + 1])
        : term.label.td;
    final share = term.percent == 0 ? '' : ' (${_qty(term.percent)}%)';
    purpose = '$label$share${_rtl ? '،' : ','} ${q.number}';
    detail = _table(
      [
        'Instalment'.td,
        'Due'.td,
        'Instalment value'.td,
        'Received before'.td,
        'This receipt'.td,
        'Remaining'.td,
      ],
      [
        [
          '${termIndex + 1}. $label$share',
          term.due.td,
          fmtMoney(value),
          fmtMoney(was),
          fmtMoney(here),
          fmtMoney(left.abs() < .005 ? 0 : left),
        ],
      ],
      widths: _receiptWidths,
      right: {2, 3, 4, 5},
    );
    after = [
      q.title.isEmpty
          ? 'As per the payment schedule of {0}, contract value {1}.'.tdArgs([
              q.number,
              fmtMoney(q.total),
            ])
          : 'As per the payment schedule of {0} ({1}), contract value {2}.'
                .tdArgs([q.number, q.title, fmtMoney(q.total)]),
      _usedText(
        repo,
        pay,
        pay.date,
        left <= 0.005
            ? 'This instalment is now fully paid.'.td
            : 'Remaining on this instalment: {0}.'.tdArgs([fmtMoney(left)]),
        // Invoices of this instalment, or billing the contract outside its
        // schedule, count on the instalment itself (as in termStatus).
        (i) =>
            i.termIndex == termIndex && i.quotationId == q.id ||
            i.termIndex == null &&
                (i.quotationId == q.id ||
                    i.quotationId == null &&
                        !i.extra &&
                        i.projectId == q.projectId),
        kept: here,
      ),
    ].join(' ');
  } else {
    purpose = 'On account'.td;
    detail = _table(
      ['Description'.td, 'Amount'.td],
      [
        [
          pay.notes.isNotEmpty ? pay.notes : 'Payment on account'.td,
          fmtMoney(pay.amount),
        ],
      ],
      widths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FixedColumnWidth(80),
      },
      right: {1},
    );
    after =
        'Received on account. It is set against the open invoices{0}, '
                'oldest first; any balance stays as credit on the account.'
            .tdArgs([
              project == null ? '' : ' of {0}'.tdArgs([project.code]),
            ]);
  }

  // How a receipt not taken on an invoice has been used so far.
  final applied = repo.appliedTo(pay);
  final credit = repo.unappliedOf(pay);

  // Project account after this receipt.
  final contract = project == null
      ? 0.0
      : repo
            .quotationsFor(project.id)
            .where((x) => x.status == QuotationStatus.accepted)
            .fold(0.0, (s, x) => s + x.total);
  final receivedToDate = project == null
      ? 0.0
      : repo.payments
            .where((o) => o.id == pay.id || Repository.receiptOrder(o, pay) < 0)
            .fold(0.0, (s, o) => s + repo.receivedFor(o, project.id));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      textDirection: _dir,
      header: (ctx) => _header(repo, 'RECEIPT'.td, pay.number),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        _partyBlock('Received from'.td, client, [
          _kv('Receipt no.'.td, pay.number),
          _kv('Date'.td, fmtDocDate(pay.date)),
          _kv('Method'.td, paymentMethodLabel(pay.method, docLang)),
          if (pay.reference.isNotEmpty) _kv('Reference'.td, pay.reference),
          if (project != null) _kv('Project'.td, project.code),
          _kv('Payment for'.td, purpose),
        ]),
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _graphite,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _text(
                      'AMOUNT RECEIVED'.td,
                      style: pw.TextStyle(
                        fontSize: _labelSize(7.5),
                        letterSpacing: _spacing(1),
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    _text(
                      dollarsInWords(pay.amount, docLang),
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              _text(
                fmtMoney(pay.amount),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 22),
        _label('Payment for'.td),
        pw.SizedBox(height: 5),
        detail,
        pw.SizedBox(height: 8),
        _text(after, style: pw.TextStyle(fontSize: 9, color: _muted)),
        if (applied.any((e) => e.$1.id != inv?.id) || credit > 0.005) ...[
          pw.SizedBox(height: 18),
          _label(
            'How this receipt was used · as of {0}'.tdArgs([
              fmtDocDate(repo.now()),
            ]),
          ),
          pw.SizedBox(height: 5),
          _table(
            ['Invoice'.td, 'Date'.td, 'Subject'.td, 'Amount set off'.td],
            [
              for (final (i, a) in applied)
                [
                  i.number,
                  fmtDocDate(i.date),
                  i.title.isNotEmpty
                      ? i.title
                      : (repo.project(i.projectId)?.name ?? ''),
                  fmtMoney(a),
                ],
              [
                '',
                '',
                term == null
                    ? 'Credit remaining on account'.td
                    : 'Credit held for the next invoices'.td,
                fmtMoney(credit),
              ],
            ],
            widths: {
              0: const pw.FixedColumnWidth(70),
              1: pw.FixedColumnWidth(_dateWidth),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(80),
            },
            right: {3},
            boldRows: {applied.length},
            softRows: {applied.length},
          ),
        ],
        if (project != null && contract > 0) ...[
          pw.SizedBox(height: 18),
          _label(
            'Project account after this receipt · {0}'.tdArgs([project.code]),
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              _tile('Contract value'.td, fmtMoney(contract)),
              _tile('Received to date'.td, fmtMoney(receivedToDate)),
              _tile(
                'Remaining on contract'.td,
                fmtMoney(contract - receivedToDate),
                strong: true,
              ),
            ],
          ),
        ],
        if (pay.notes.isNotEmpty && (inv != null || term != null)) ...[
          pw.SizedBox(height: 14),
          _label('Notes'.td),
          pw.SizedBox(height: 3),
          _text(pay.notes, style: const pw.TextStyle(fontSize: 9)),
        ],
        if (pay.method == PaymentMethod.cheque) ...[
          pw.SizedBox(height: 12),
          _text(
            'Payment by cheque is valid subject to collection.'.td,
            style: pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
        pw.SizedBox(height: 40),
        _signatures(repo, 'Received by (name and signature)'.td),
      ],
    ),
  );
  return pdf.save();
}

const _receiptWidths = {
  0: pw.FlexColumnWidth(2.2),
  1: pw.FlexColumnWidth(2.4),
  2: pw.FixedColumnWidth(66),
  3: pw.FixedColumnWidth(66),
  4: pw.FixedColumnWidth(62),
  5: pw.FixedColumnWidth(60),
};

Future<void> shareReceiptPdf(Repository repo, Payment pay) async {
  final numbered = await repo.withReceiptNumber(pay);
  final bytes = await buildReceiptPdf(repo, numbered);
  await Printing.sharePdf(bytes: bytes, filename: '${numbered.number}.pdf');
}

/// Builds the detailed project statement: by phase, by trade and item,
/// and the account movements.
Future<Uint8List> buildProjectStatementPdf(
  Repository repo,
  ProjectStatement built,
) async {
  // The lines and phases are worded again when built in another language.
  final ps = built.lang == docLang
      ? built
      : buildProjectStatement(repo, built.project.id, lang: docLang);
  final info = repo.companyInfo;
  final st = ps.account;
  final p = ps.project;
  final pdf = pw.Document(
    theme: await _theme(repo),
    title: 'Project statement {0}'.tdArgs([p.code]),
    author: repo.companyName,
  );
  String m(double v) => v.abs() < .005 ? '—' : fmtMoney(v);

  final phaseRows = <List<String>>[
    for (final ph in ps.phases)
      [
        ph.name +
            (ph.stage?.id == ps.currentStageId ? '  ${'(current)'.td}' : ''),
        ph.tasks.isEmpty
            ? '—'
            : '{0} of {1}'.tdArgs([ph.tasksDone, ph.tasks.length]),
        m(ph.invoiced),
        m(ph.received),
        m(ph.balance),
      ],
    if (st.advances > 0.005)
      ['Advances not yet set off'.td, '', '—', m(st.advances), m(-st.advances)],
    [
      'Total'.td,
      '{0} of {1}'.tdArgs([
        ps.phases.fold<int>(0, (s, ph) => s + ph.tasksDone),
        ps.phases.fold<int>(0, (s, ph) => s + ph.tasks.length),
      ]),
      fmtMoney(st.invoiced),
      fmtMoney(st.received),
      fmtMoney(st.closing),
    ],
  ];

  final scheduleRows = <List<String>>[
    for (final l in ps.schedule)
      [
        [
          if (ps.schedule.any((x) => x.quotation.id != l.quotation.id))
            l.quotation.number,
          '${l.index + 1}. ${l.label}',
        ].join(' · '),
        l.status.term.due.td,
        l.status.term.percent == 0 ? '' : '${_qty(l.status.term.percent)}%',
        fmtMoney(l.status.value),
        l.status.invoices.isEmpty
            ? '—'
            : l.status.invoices.map((i) => i.number).join(', '),
        m(l.status.received),
        l.status.settled ? 'Paid'.td : fmtMoney(l.status.remaining),
      ],
  ];
  if (scheduleRows.isNotEmpty) {
    final value = ps.schedule.fold(0.0, (s, l) => s + l.status.value);
    final got = ps.schedule.fold(0.0, (s, l) => s + l.status.received);
    scheduleRows.add([
      'Total'.td,
      '',
      '',
      fmtMoney(value),
      '',
      fmtMoney(got),
      fmtMoney(value - got),
    ]);
  }

  final layerRows = <List<String>>[];
  final layerHeads = <int>{};
  final layerTotals = <int>{};
  var g = 0;
  for (final l in ps.layers) {
    g++;
    final sectioned = ps.layers.length > 1 || l.name.isNotEmpty;
    if (sectioned) {
      layerHeads.add(layerRows.length);
      layerRows.add([
        '$g',
        (l.name.isEmpty ? 'General'.td : l.name.td).toUpperCase(),
        '',
        m(l.contractAmount),
        m(l.invoicedAmount),
        l.contractAmount == 0 ? '' : _pct(l.percent),
      ]);
    }
    for (final (k, i) in l.items.indexed) {
      layerRows.add([
        sectioned ? '$g.${k + 1}' : '${k + 1}',
        i.description.td,
        i.unit.td,
        m(i.contractAmount),
        m(i.invoicedAmount),
        i.contractAmount == 0 ? '' : _pct(i.percent),
      ]);
    }
  }
  final contractNet = ps.layers.fold(0.0, (s, l) => s + l.contractAmount);
  final invoicedNet = ps.layers.fold(0.0, (s, l) => s + l.invoicedAmount);
  layerTotals.add(layerRows.length);
  layerRows.add([
    '',
    'Total before VAT'.td,
    '',
    fmtMoney(contractNet),
    fmtMoney(invoicedNet),
    contractNet == 0 ? '' : _pct(invoicedNet / contractNet * 100),
  ]);

  final moves = <List<String>>[
    for (final l in st.lines)
      [
        fmtDocDate(l.date),
        l.reference,
        l.description,
        l.debit == 0 ? '' : fmtMoney(l.debit),
        l.credit == 0 ? '' : fmtMoney(l.credit),
        fmtMoney(l.balance),
      ],
    [
      fmtDocDate(st.to),
      '',
      'Closing balance'.td,
      fmtMoney(st.invoiced),
      fmtMoney(st.received),
      fmtMoney(st.closing),
    ],
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      textDirection: _dir,
      header: (ctx) => _header(
        repo,
        'PROJECT STATEMENT'.td,
        'As of {0}'.tdArgs([fmtDocDate(st.to)]),
      ),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        _partyBlock('Prepared for'.td, st.client, [
          _kv('Project'.td, p.code),
          _kv('Name'.td, p.name),
          if (p.location.isNotEmpty) _kv('Location'.td, p.location),
          _kv('Phase'.td, repo.stage(p.stageId)?.name.td ?? '—'),
          _kv('Currency'.td, 'USD'),
        ]),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _tile('Contract value'.td, fmtMoney(ps.contractValue)),
            _tile('Invoiced'.td, fmtMoney(st.invoiced)),
            _tile('Received'.td, fmtMoney(st.received)),
            if (st.advances > 0.005) ...[
              _tile('Credit held'.td, fmtMoney(st.advances)),
              _tile(
                'Due on invoices'.td,
                fmtMoney(st.dueOnInvoices),
                strong: true,
              ),
            ] else ...[
              _tile('Billed'.td, _pct(ps.billedPercent)),
              st.closing < -0.005
                  ? _tile(
                      'Credit balance'.td,
                      fmtMoney(-st.closing),
                      strong: true,
                    )
                  : _tile('Balance due'.td, fmtMoney(st.closing), strong: true),
            ],
          ],
        ),
        pw.SizedBox(height: 18),
        _label('1 · By phase'.td),
        pw.SizedBox(height: 5),
        _table(
          [
            'Phase'.td,
            'Tasks done'.td,
            'Invoiced'.td,
            'Received'.td,
            'Balance'.td,
          ],
          phaseRows,
          widths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FixedColumnWidth(64),
            2: const pw.FixedColumnWidth(72),
            3: const pw.FixedColumnWidth(72),
            4: const pw.FixedColumnWidth(72),
          },
          right: {1, 2, 3, 4},
          boldRows: {phaseRows.length - 1},
          softRows: {phaseRows.length - 1},
        ),
        for (final ph in ps.phases)
          if (ph.tasks.isNotEmpty || ph.invoices.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(
                    ph.name,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  for (final t in ph.tasks)
                    pw.Padding(
                      padding: const pw.EdgeInsetsDirectional.only(
                        start: 8,
                        top: 2,
                      ),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 60,
                            child: _text(
                              _taskState(t.status),
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: t.status == TaskStatus.done
                                    ? _blue
                                    : _muted,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: _text(
                              t.title,
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ),
                          _text(
                            t.dueDate == null ? '' : fmtDocDate(t.dueDate),
                            style: pw.TextStyle(fontSize: 8, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  for (final o in ph.invoices)
                    pw.Padding(
                      padding: const pw.EdgeInsetsDirectional.only(
                        start: 8,
                        top: 2,
                      ),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 60,
                            child: _text(
                              o.invoice.number,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Expanded(
                            child: _text(
                              o.invoice.title,
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ),
                          _text(
                            '{0} · paid {1}'.tdArgs([
                              fmtMoney(o.invoice.total),
                              fmtMoney(o.paid),
                            ]),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        if (scheduleRows.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _label('2 · Payment schedule'.td),
          pw.SizedBox(height: 5),
          _table(
            [
              'Instalment'.td,
              'Due'.td,
              'Share'.td,
              'Value'.td,
              'Invoice'.td,
              'Received'.td,
              'Remaining'.td,
            ],
            scheduleRows,
            widths: {
              0: const pw.FlexColumnWidth(2.6),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FixedColumnWidth(36),
              3: const pw.FixedColumnWidth(62),
              4: const pw.FixedColumnWidth(56),
              5: const pw.FixedColumnWidth(62),
              6: const pw.FixedColumnWidth(62),
            },
            right: {2, 3, 5, 6},
            boldRows: {scheduleRows.length - 1},
            softRows: {scheduleRows.length - 1},
          ),
        ],
        if (ps.layers.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _label(
            '{0} · By trade and item (before VAT, fee included)'.tdArgs([
              scheduleRows.isEmpty ? 2 : 3,
            ]),
          ),
          pw.SizedBox(height: 5),
          _table(
            [
              '#',
              'Item'.td,
              'Unit'.td,
              'Contract'.td,
              'Invoiced'.td,
              'Billed'.td,
            ],
            layerRows,
            widths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(70),
              4: const pw.FixedColumnWidth(70),
              5: const pw.FixedColumnWidth(40),
            },
            right: {3, 4, 5},
            boldRows: {...layerHeads, ...layerTotals},
            softRows: {...layerHeads, ...layerTotals},
          ),
        ],
        pw.SizedBox(height: 18),
        _label(
          '{0} · Account movements'.tdArgs([
            2 + (scheduleRows.isEmpty ? 0 : 1) + (ps.layers.isEmpty ? 0 : 1),
          ]),
        ),
        pw.SizedBox(height: 5),
        _table(
          [
            'Date'.td,
            'Reference'.td,
            'Description'.td,
            'Debit'.td,
            'Credit@@column'.td,
            'Balance'.td,
          ],
          moves,
          widths: {
            0: pw.FixedColumnWidth(_dateWidth),
            1: const pw.FixedColumnWidth(64),
            2: const pw.FlexColumnWidth(4),
            3: const pw.FixedColumnWidth(62),
            4: const pw.FixedColumnWidth(62),
            5: const pw.FixedColumnWidth(66),
          },
          right: {3, 4, 5},
          boldRows: {moves.length - 1},
          softRows: {moves.length - 1},
        ),
        pw.SizedBox(height: 18),
        if (info['bank']?.isNotEmpty ?? false) ...[
          _label('Bank details'.td),
          pw.SizedBox(height: 3),
          _text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        _text(
          st.advances > 0.005
              ? 'Due on issued invoices: {0}. Credit of {1} is held on '
                        'this project: every payment received settles the '
                        'issued invoices oldest first, and the rest is set '
                        'against the next invoices. Net account balance: {2}. '
                        'Please report any difference within 15 days of this '
                        'statement.'
                    .tdArgs([
                      fmtMoney(st.dueOnInvoices),
                      fmtMoney(st.advances),
                      _net(st.closing),
                    ])
              : st.closing > 0.005
              ? 'Balance due: {0}. Please report any '
                        'difference within 15 days of this statement.'
                    .tdArgs([fmtMoney(st.closing)])
              : st.closing < -0.005
              ? 'The project account is in credit by {0}.'.tdArgs([
                  fmtMoney(-st.closing),
                ])
              : 'The project account is fully settled. Thank you.'.td,
          style: pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
        pw.SizedBox(height: 30),
        _signatures(repo, 'Client confirmation'.td),
      ],
    ),
  );
  return pdf.save();
}

String _taskState(TaskStatus s) => switch (s) {
  TaskStatus.done => 'Done'.td,
  TaskStatus.inProgress => 'In progress'.td,
  _ => 'To do'.td,
};

Future<void> shareProjectStatementPdf(
  Repository repo,
  ProjectStatement ps,
) async {
  final bytes = await buildProjectStatementPdf(repo, ps);
  await Printing.sharePdf(
    bytes: bytes,
    filename:
        '${_fileSafe('Statement@@file'.td)}-${ps.project.code}-'
        '${ps.account.to.toIso8601String().substring(0, 10)}.pdf',
  );
}
