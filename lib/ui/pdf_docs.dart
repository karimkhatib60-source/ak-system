import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/boq_library.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/statement.dart';
import 'format.dart';

const _graphite = PdfColor.fromInt(0xFF14171C);
const _blue = PdfColor.fromInt(0xFF2F6BEB);
const _muted = PdfColor.fromInt(0xFF5F6670);
const _line = PdfColor.fromInt(0xFFE2E4E8);
const _soft = PdfColor.fromInt(0xFFF4F5F7);

Future<pw.ThemeData> _theme() async {
  Future<pw.Font> f(String w) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope-$w.ttf'));
  return pw.ThemeData.withFont(base: await f('400'), bold: await f('700'));
}

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
      ? repo.companyInfo['terms'] ?? ''
      : (doc as Quotation).terms;
  final client = repo.client(clientId);
  final project = repo.project(projectId);
  final info = repo.companyInfo;
  final paid = isInvoice ? repo.paidOn(doc) : 0.0;

  final pdf = pw.Document(
    theme: await _theme(),
    title: '$number ${isInvoice ? 'Invoice' : 'Quotation'}',
    author: repo.companyName,
  );

  pw.Widget label(String s) => pw.Text(
    s.toUpperCase(),
    style: const pw.TextStyle(fontSize: 7.5, color: _muted, letterSpacing: 1),
  );

  pw.Widget moneyRow(String l, double v, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            l,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 9.5,
              fontWeight: bold ? pw.FontWeight.bold : null,
            ),
          ),
        ),
        pw.Text(
          fmtMoney(v),
          style: pw.TextStyle(
            fontSize: bold ? 11 : 9.5,
            fontWeight: bold ? pw.FontWeight.bold : null,
          ),
        ),
      ],
    ),
  );

  final contact = [
    info['address'],
    info['phone'],
    info['email'],
    info['website'],
  ].whereType<String>().where((s) => s.isNotEmpty).join('  ·  ');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (ctx) => _header(
        repo.companyName,
        isInvoice ? 'INVOICE' : 'QUOTATION',
        number,
      ),
      footer: (ctx) => _footer(ctx, contact),
      build: (ctx) => [
        // Parties and dates.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label(isInvoice ? 'Bill to' : 'Prepared for'),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    client?.name ?? '—',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (client != null && client.company.isNotEmpty)
                    pw.Text(
                      client.company,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (client != null)
                    pw.Text(
                      [
                        client.phone,
                        client.email,
                        client.country,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
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
                  _kv('Date', fmtDate(date)),
                  if (second != null)
                    _kv(
                      isInvoice ? 'Payment due' : 'Valid until',
                      fmtDate(second),
                    ),
                  if (project != null) _kv('Project', project.code),
                  if (info['tax_number']?.isNotEmpty ?? false)
                    _kv('VAT no.', info['tax_number']!),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        if (title.isNotEmpty || project != null) ...[
          label('Subject'),
          pw.SizedBox(height: 3),
          pw.Text(
            title.isNotEmpty ? title : project!.name,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          if (project != null && project.location.isNotEmpty)
            pw.Text(
              '${project.name} · ${project.location}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
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
                    moneyRow('Cost subtotal', doc.subtotal),
                    moneyRow(
                      'Cost-plus fee ${_qty(doc.markupRate)}%',
                      doc.markup,
                    ),
                  ] else
                    moneyRow('Subtotal', doc.subtotal + doc.markup),
                  if (doc.discount != 0) moneyRow('Discount', -doc.discount),
                  moneyRow('VAT ${_qty(doc.vatRate)}%', doc.vat),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    height: 1,
                    color: _graphite,
                  ),
                  moneyRow('Total (USD)', doc.total, bold: true),
                  if (isInvoice && paid > 0) ...[
                    moneyRow('Paid', -paid),
                    moneyRow('Balance due', doc.total - paid, bold: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        if (notes.isNotEmpty) ...[
          label('Notes'),
          pw.SizedBox(height: 3),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        if (isInvoice && (info['bank']?.isNotEmpty ?? false)) ...[
          label('Payment details'),
          pw.SizedBox(height: 3),
          pw.Text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        if (terms.isNotEmpty) ...[
          label('Terms and conditions'),
          pw.SizedBox(height: 3),
          pw.Text(
            terms,
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
        if (!isInvoice) ...[
          pw.SizedBox(height: 36),
          pw.Row(
            children: [
              pw.Expanded(child: _signature('For ${repo.companyName}')),
              pw.SizedBox(width: 40),
              pw.Expanded(child: _signature('Client acceptance')),
            ],
          ),
        ],
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _kv(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 70,
        child: pw.Text(
          k,
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
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
    pw.Text(who, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
    pw.Text(
      'Name, signature and date',
      style: const pw.TextStyle(fontSize: 7.5, color: _muted),
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
    child: pw.Text(
      t,
      style: style,
      textAlign: rightCols.contains(col) ? pw.TextAlign.right : null,
    ),
  );
  pw.TableRow row(
    List<String> cells, {
    pw.TextStyle style = cell,
    PdfColor? fill,
  }) => pw.TableRow(
    decoration: pw.BoxDecoration(
      color: fill,
      border: const pw.Border(bottom: pw.BorderSide(color: _line, width: .6)),
    ),
    children: [for (var k = 0; k < 6; k++) c(cells[k], k, style)],
  );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _graphite),
      children: [
        for (final (k, h) in [
          '#',
          'Description',
          'Qty',
          'Unit',
          'Rate',
          'Amount',
        ].indexed)
          c(h, k, head),
      ],
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
          ['$g', name.isEmpty ? 'General' : name.toUpperCase(), '', '', '', ''],
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
          i.description,
          _qty(i.quantity),
          i.unit,
          fmtMoney(i.rate * factor),
          fmtMoney(amount),
        ]),
      );
    }
    if (showHead && groups.length > 1) {
      rows.add(
        row([
          '',
          'Total ${name.isEmpty ? 'general' : name}',
          '',
          '',
          '',
          fmtMoney(sum),
        ], style: bold),
      );
    }
  }

  return pw.Table(
    columnWidths: {
      0: const pw.FixedColumnWidth(26),
      1: const pw.FlexColumnWidth(5),
      2: const pw.FixedColumnWidth(36),
      3: const pw.FixedColumnWidth(50),
      4: const pw.FixedColumnWidth(68),
      5: const pw.FixedColumnWidth(76),
    },
    children: rows,
  );
}

pw.Widget _header(String company, String title, String number) => pw.Column(
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
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
              pw.Text(
                company,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: _graphite,
                ),
              ),
              pw.Text(
                'Design · Consultancy · Contracting',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _graphite,
                letterSpacing: 2,
              ),
            ),
            pw.Text(
              number,
              style: const pw.TextStyle(fontSize: 10, color: _blue),
            ),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 10),
    pw.Container(height: 2, color: _graphite),
    pw.SizedBox(height: 16),
  ],
);

pw.Widget _footer(pw.Context ctx, String contact) => pw.Column(
  children: [
    pw.Container(height: 0.6, color: _line),
    pw.SizedBox(height: 6),
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            contact,
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: _muted),
        ),
      ],
    ),
  ],
);

String _contact(Map<String, String> info) => [
  info['address'],
  info['phone'],
  info['email'],
  info['website'],
].whereType<String>().where((s) => s.isNotEmpty).join('  ·  ');

/// Builds the branded statement of account for a client.
Future<Uint8List> buildStatementPdf(Repository repo, Statement st) async {
  final info = repo.companyInfo;
  final client = st.client;
  final pdf = pw.Document(
    theme: await _theme(),
    title: 'Statement of account ${client.name}',
    author: repo.companyName,
  );
  pw.Widget label(String s) => pw.Text(
    s.toUpperCase(),
    style: const pw.TextStyle(fontSize: 7.5, color: _muted, letterSpacing: 1),
  );
  const cell = pw.TextStyle(fontSize: 8.5);
  final bold = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  final head = pw.TextStyle(
    color: PdfColors.white,
    fontWeight: pw.FontWeight.bold,
    fontSize: 8,
  );
  const pad = pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5);
  String m(double v) => v == 0 ? '' : fmtMoney(v);

  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    required Map<int, pw.TableColumnWidth> widths,
    required Set<int> right,
    Set<int> boldRows = const {},
    Set<int> softRows = const {},
  }) {
    pw.Widget c(String t, int k, pw.TextStyle style) => pw.Padding(
      padding: pad,
      child: pw.Text(
        t,
        style: style,
        textAlign: right.contains(k) ? pw.TextAlign.right : null,
      ),
    );
    return pw.Table(
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _graphite),
          children: [for (final (k, h) in headers.indexed) c(h, k, head)],
        ),
        for (final (r, row) in rows.indexed)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: softRows.contains(r) ? _soft : null,
              border: const pw.Border(
                bottom: pw.BorderSide(color: _line, width: .6),
              ),
            ),
            children: [
              for (final (k, t) in row.indexed)
                c(t, k, boldRows.contains(r) ? bold : cell),
            ],
          ),
      ],
    );
  }

  pw.Widget tile(String l, double v, {bool strong = false}) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: strong ? _graphite : _soft,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 6.5,
              letterSpacing: .8,
              color: strong ? PdfColors.white : _muted,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            fmtMoney(v),
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

  final moves = <List<String>>[
    if (st.from != null)
      [fmtDate(st.from), '', 'Opening balance', '', '', fmtMoney(st.opening)],
    for (final l in st.lines)
      [
        fmtDate(l.date),
        l.reference,
        l.description,
        m(l.debit),
        m(l.credit),
        fmtMoney(l.balance),
      ],
    [
      fmtDate(st.to),
      '',
      'Closing balance',
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
      header: (ctx) =>
          _header(repo.companyName, 'STATEMENT', 'As of ${fmtDate(st.to)}'),
      footer: (ctx) => _footer(ctx, _contact(info)),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('Statement of account for'),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    client.name,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  if (client.company.isNotEmpty)
                    pw.Text(
                      client.company,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  pw.Text(
                    [
                      client.phone,
                      client.email,
                      client.country,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Container(
              width: 200,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv(
                    'Period',
                    st.from == null
                        ? 'All to ${fmtDate(st.to)}'
                        : '${fmtDate(st.from)} – ${fmtDate(st.to)}',
                  ),
                  _kv(
                    'Project',
                    st.project == null
                        ? 'All projects'
                        : '${st.project!.code} ${st.project!.name}',
                  ),
                  _kv('Currency', 'USD'),
                  if (info['tax_number']?.isNotEmpty ?? false)
                    _kv('VAT no.', info['tax_number']!),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            if (st.contractValue > 0) tile('Agreed contract', st.contractValue),
            if (st.from != null) tile('Opening balance', st.opening),
            tile('Invoiced', st.invoiced),
            tile('Received', st.received),
            tile('Balance due', st.closing, strong: true),
          ],
        ),
        pw.SizedBox(height: 16),
        label('Account movements'),
        pw.SizedBox(height: 5),
        table(
          ['Date', 'Reference', 'Description', 'Debit', 'Credit', 'Balance'],
          moves,
          widths: {
            0: const pw.FixedColumnWidth(66),
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
          label('Open invoices'),
          pw.SizedBox(height: 5),
          table(
            ['Invoice', 'Date', 'Due', 'Amount', 'Paid', 'Balance', 'Late'],
            [
              for (final o in st.open)
                [
                  o.invoice.number,
                  fmtDate(o.invoice.date),
                  fmtDate(o.invoice.dueDate),
                  fmtMoney(o.invoice.total),
                  fmtMoney(o.paid),
                  fmtMoney(o.balance),
                  o.daysOverdue > 0 ? '${o.daysOverdue} days' : 'Not due',
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FixedColumnWidth(66),
              2: const pw.FixedColumnWidth(66),
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
              'Not yet due',
              '1–30 days',
              '31–60 days',
              '61–90 days',
              '90+ days',
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
          label('Bank details'),
          pw.SizedBox(height: 3),
          pw.Text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          st.closing > 0.005
              ? 'Kindly settle the balance due of ${fmtMoney(st.closing)}. '
                    'Please report any difference within 15 days of this '
                    'statement; otherwise it is considered accepted.'
              : 'Your account is fully settled. Thank you.',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
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
                  pw.Text(
                    'For ${repo.companyName}',
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
                  pw.Text(
                    'Client confirmation',
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
  final name = st.client.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'Statement-$name-${st.to.toIso8601String().substring(0, 10)}.pdf',
  );
}
