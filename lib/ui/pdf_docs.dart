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
  final setOff = isInvoice ? repo.advanceOn(doc) : 0.0;

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

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (ctx) =>
          _header(repo, isInvoice ? 'INVOICE' : 'QUOTATION', number),
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
                    if (paid - setOff > 0.005)
                      moneyRow('Received', -(paid - setOff)),
                    if (setOff > 0.005)
                      moneyRow('Set off from advance payments', -setOff),
                    moneyRow('Balance due', repo.balanceOf(doc), bold: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        if (!isInvoice && (doc as Quotation).paymentTerms.isNotEmpty) ...[
          label('Payment schedule'),
          pw.SizedBox(height: 5),
          _scheduleTable(doc),
          pw.SizedBox(height: 16),
        ],
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

/// A quotation's payment terms: instalment, when due, share and amount.
pw.Widget _scheduleTable(Quotation q) {
  final terms = q.paymentTerms;
  final rows = [
    for (final (k, t) in terms.indexed)
      [
        '${k + 1}',
        t.label.isEmpty ? 'Payment ${k + 1}' : t.label,
        t.due,
        t.percent == 0 ? '' : '${_qty(t.percent)}%',
        fmtMoney(t.valueOf(q.total)),
      ],
  ];
  final pct = terms.fold(0.0, (s, t) => s + t.percent);
  final sum = terms.fold(0.0, (s, t) => s + t.valueOf(q.total));
  rows.add(['', 'Total', '', pct == 0 ? '' : '${_qty(pct)}%', fmtMoney(sum)]);
  return _table(
    ['#', 'Instalment', 'Due', 'Share', 'Amount'],
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
              pw.Text(
                repo.companyName,
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

pw.Widget _footer(pw.Context ctx, Repository repo) {
  final links = companyLinks(repo.companyInfo);
  final address = repo.companyInfo['address'] ?? '';
  const style = pw.TextStyle(fontSize: 7.5, color: _muted);
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
                  pw.Text(address.split('\n').first, style: style),
                for (final l in links)
                  pw.UrlLink(
                    destination: l.url,
                    child: pw.Text(
                      '${_linkLabel(l.kind)}${l.display}',
                      style: style,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: style),
        ],
      ),
    ],
  );
}

String _linkLabel(String kind) => kind == 'instagram' ? 'Instagram ' : '';

/// Builds the branded statement of account for a client.
Future<Uint8List> buildStatementPdf(Repository repo, Statement st) async {
  final info = repo.companyInfo;
  final client = st.client;
  final pdf = pw.Document(
    theme: await _theme(),
    title: 'Statement of account ${client.name}',
    author: repo.companyName,
  );
  const label = _label;
  const table = _table;
  String m(double v) => v == 0 ? '' : fmtMoney(v);
  pw.Widget tile(String l, double v, {bool strong = false}) =>
      _tile(l, fmtMoney(v), strong: strong);

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
      header: (ctx) => _header(repo, 'STATEMENT', 'As of ${fmtDate(st.to)}'),
      footer: (ctx) => _footer(ctx, repo),
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
            if (st.advances > 0.005) ...[
              tile('Advances held', st.advances),
              tile('Due on invoices', st.dueOnInvoices, strong: true),
            ] else if (st.closing < -0.005)
              tile('Credit balance', -st.closing, strong: true)
            else
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
        if (st.advances > 0.005)
          pw.Text(
            'Advances held: ${fmtMoney(st.advances)} received on payment '
            'terms or on account and not yet set against an invoice. An '
            'advance on a payment term is set against that term\'s invoice; '
            'money on account against the next invoices. Due on issued '
            'invoices: '
            '${fmtMoney(st.dueOnInvoices)}. Net account balance: '
            '${st.closing < 0 ? 'credit ' : ''}${fmtMoney(st.closing.abs())}. '
            'Please report any difference within 15 days of this '
            'statement; otherwise it is considered accepted.',
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          )
        else
          pw.Text(
            st.closing > 0.005
                ? 'Kindly settle the balance due of ${fmtMoney(st.closing)}. '
                      'Please report any difference within 15 days of this '
                      'statement; otherwise it is considered accepted.'
                : st.closing < -0.005
                ? 'Your account is in credit by ${fmtMoney(-st.closing)}. '
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

pw.Widget _label(String s) => pw.Text(
  s.toUpperCase(),
  style: const pw.TextStyle(fontSize: 7.5, color: _muted, letterSpacing: 1),
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
        repeat: true,
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

/// A summary figure box; [strong] is the dark one for the key figure.
pw.Widget _tile(String l, String value, {bool strong = false}) => pw.Expanded(
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

/// Two signature lines: the company on the left, [other] on the right.
pw.Widget _signatures(Repository repo, String other) {
  pw.Widget line(String t) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: .6, color: _graphite),
        pw.SizedBox(height: 4),
        pw.Text(t, style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
  return pw.Row(
    children: [
      line('For ${repo.companyName}'),
      pw.SizedBox(width: 60),
      line(other),
    ],
  );
}

/// The "prepared for" client block with a facts box on the right.
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
              pw.Text(
                client?.name ?? '—',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (client != null && client.company.isNotEmpty)
                pw.Text(client.company, style: const pw.TextStyle(fontSize: 9)),
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
  final before = repo.receivedBefore(pay);
  final pdf = pw.Document(
    theme: await _theme(),
    title: '${pay.number} Receipt',
    author: repo.companyName,
  );

  // What the money was for, and where that stands after this receipt.
  final String purpose;
  final pw.Widget detail;
  final String after;
  var extra = 0.0; // paid above the invoice or instalment
  if (inv != null) {
    // Advances and money on account set against the invoice by the
    // receipt's date count as received too.
    final advance = repo.advanceOn(inv, until: pay.date);
    final prior = before + advance;
    final total = (inv.total * 100).round() / 100;
    final rest = total - prior - pay.amount;
    final left = rest > 0 ? rest : 0.0;
    extra = rest < -0.005 ? -rest : 0;
    purpose = 'Invoice ${inv.number}';
    detail = _table(
      [
        'Invoice',
        'Subject',
        'Invoice total',
        'Received before',
        'This receipt',
        'Balance',
      ],
      [
        [
          inv.number,
          inv.title.isNotEmpty ? inv.title : (project?.name ?? ''),
          fmtMoney(inv.total),
          fmtMoney(prior),
          fmtMoney(pay.amount),
          fmtMoney(left.abs() < .005 ? 0 : left),
        ],
      ],
      widths: _receiptWidths,
      right: {2, 3, 4, 5},
    );
    after = left <= 0.005
        ? '${inv.number} is now fully paid. Thank you.'
              '${extra > 0 ? ' The extra ${fmtMoney(extra)} is held as credit '
                        'on the account.' : ''}'
        : 'Remaining on ${inv.number}: ${fmtMoney(left)}.';
  } else if (q != null && term != null) {
    final value = (term.valueOf(q.total) * 100).round() / 100;
    // Everything received on this term up to the day before, plus earlier
    // receipts on the term the same day.
    final day = DateTime(pay.date.year, pay.date.month, pay.date.day);
    final sameDayBefore = repo.payments
        .where(
          (o) =>
              !o.onInvoice &&
              o.quotationId == q.id &&
              o.termIndex == termIndex &&
              DateTime(o.date.year, o.date.month, o.date.day) == day &&
              Repository.receiptOrder(o, pay) < 0,
        )
        .fold(0.0, (s, o) => s + o.amount);
    final prior =
        repo
            .termStatus(
              q,
              termIndex!,
              until: day.subtract(const Duration(days: 1)),
            )
            .received +
        sameDayBefore;
    final rest = value - prior - pay.amount;
    final left = rest > 0 ? rest : 0.0;
    extra = rest < -0.005 ? (-rest < pay.amount ? -rest : pay.amount) : 0;
    final label = term.label.isEmpty ? 'Payment ${termIndex + 1}' : term.label;
    final share = term.percent == 0 ? '' : ' (${_qty(term.percent)}%)';
    purpose = '$label$share, ${q.number}';
    detail = _table(
      [
        'Instalment',
        'Due',
        'Instalment value',
        'Received before',
        'This receipt',
        'Remaining',
      ],
      [
        [
          '${termIndex + 1}. $label$share',
          term.due,
          fmtMoney(value),
          fmtMoney(prior),
          fmtMoney(pay.amount),
          fmtMoney(left.abs() < .005 ? 0 : left),
        ],
      ],
      widths: _receiptWidths,
      right: {2, 3, 4, 5},
    );
    after =
        'As per the payment schedule of ${q.number}'
        '${q.title.isEmpty ? '' : ' (${q.title})'}, contract value '
        '${fmtMoney(q.total)}. '
        '${left <= 0.005 ? 'This instalment is now fully paid.' : 'Remaining on this instalment: ${fmtMoney(left)}.'}'
        '${extra > 0 ? ' The extra ${fmtMoney(extra)} is held as credit on the account.' : ''}';
  } else {
    purpose = 'On account';
    detail = _table(
      ['Description', 'Amount'],
      [
        [
          pay.notes.isNotEmpty ? pay.notes : 'Payment on account',
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
        'Received on account. It is set against the open invoices'
        '${project == null ? '' : ' of ${project.code}'}, oldest first; '
        'any balance stays as credit on the account.';
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
      header: (ctx) => _header(repo, 'RECEIPT', pay.number),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        _partyBlock('Received from', client, [
          _kv('Receipt no.', pay.number),
          _kv('Date', fmtDate(pay.date)),
          _kv('Method', paymentMethodLabel(pay.method)),
          if (pay.reference.isNotEmpty) _kv('Reference', pay.reference),
          if (project != null) _kv('Project', project.code),
          _kv('Payment for', purpose),
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
                    pw.Text(
                      'AMOUNT RECEIVED',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        letterSpacing: 1,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      dollarsInWords(pay.amount),
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
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
        _label('Payment for'),
        pw.SizedBox(height: 5),
        detail,
        pw.SizedBox(height: 8),
        pw.Text(after, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        if (applied.isNotEmpty || credit > 0.005) ...[
          pw.SizedBox(height: 18),
          _label(
            '${inv == null ? 'Set against invoices' : 'Paid above ${inv.number}'}'
            ' · as of ${fmtDate(repo.now())}',
          ),
          pw.SizedBox(height: 5),
          _table(
            ['Invoice', 'Date', 'Subject', 'Amount set off'],
            [
              for (final (i, a) in applied)
                [
                  i.number,
                  fmtDate(i.date),
                  i.title.isNotEmpty
                      ? i.title
                      : (repo.project(i.projectId)?.name ?? ''),
                  fmtMoney(a),
                ],
              [
                '',
                '',
                term == null
                    ? 'Credit remaining on account'
                    : extra > 0
                    ? 'Credit held: for this instalment, the rest on account'
                    : 'Held for the invoice of this instalment',
                fmtMoney(credit),
              ],
            ],
            widths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FixedColumnWidth(66),
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
          _label('Project account after this receipt · ${project.code}'),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              _tile('Contract value', fmtMoney(contract)),
              _tile('Received to date', fmtMoney(receivedToDate)),
              _tile(
                'Remaining on contract',
                fmtMoney(contract - receivedToDate),
                strong: true,
              ),
            ],
          ),
        ],
        if (pay.notes.isNotEmpty && (inv != null || term != null)) ...[
          pw.SizedBox(height: 14),
          _label('Notes'),
          pw.SizedBox(height: 3),
          pw.Text(pay.notes, style: const pw.TextStyle(fontSize: 9)),
        ],
        if (pay.method == PaymentMethod.cheque) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Payment by cheque is valid subject to collection.',
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
        ],
        pw.SizedBox(height: 40),
        _signatures(repo, 'Received by (name and signature)'),
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
  ProjectStatement ps,
) async {
  final info = repo.companyInfo;
  final st = ps.account;
  final p = ps.project;
  final pdf = pw.Document(
    theme: await _theme(),
    title: 'Project statement ${p.code}',
    author: repo.companyName,
  );
  String m(double v) => v.abs() < .005 ? '—' : fmtMoney(v);

  final phaseRows = <List<String>>[
    for (final ph in ps.phases)
      [
        ph.name + (ph.stage?.id == ps.currentStageId ? '  (current)' : ''),
        ph.tasks.isEmpty ? '—' : '${ph.tasksDone} of ${ph.tasks.length}',
        m(ph.invoiced),
        m(ph.received),
        m(ph.balance),
      ],
    if (st.advances > 0.005)
      ['Advances not yet set off', '', '—', m(st.advances), m(-st.advances)],
    [
      'Total',
      '${ps.phases.fold(0, (s, ph) => s + ph.tasksDone)} of '
          '${ps.phases.fold(0, (s, ph) => s + ph.tasks.length)}',
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
        l.status.term.due,
        l.status.term.percent == 0 ? '' : '${_qty(l.status.term.percent)}%',
        fmtMoney(l.status.value),
        l.status.invoices.isEmpty
            ? '—'
            : l.status.invoices.map((i) => i.number).join(', '),
        m(l.status.received),
        l.status.settled ? 'Paid' : fmtMoney(l.status.remaining),
      ],
  ];
  if (scheduleRows.isNotEmpty) {
    final value = ps.schedule.fold(0.0, (s, l) => s + l.status.value);
    final got = ps.schedule.fold(0.0, (s, l) => s + l.status.received);
    scheduleRows.add([
      'Total',
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
        (l.name.isEmpty ? 'General' : l.name).toUpperCase(),
        '',
        m(l.contractAmount),
        m(l.invoicedAmount),
        l.contractAmount == 0 ? '' : _pct(l.percent),
      ]);
    }
    for (final (k, i) in l.items.indexed) {
      layerRows.add([
        sectioned ? '$g.${k + 1}' : '${k + 1}',
        i.description,
        i.unit,
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
    'Total before VAT',
    '',
    fmtMoney(contractNet),
    fmtMoney(invoicedNet),
    contractNet == 0 ? '' : _pct(invoicedNet / contractNet * 100),
  ]);

  final moves = <List<String>>[
    for (final l in st.lines)
      [
        fmtDate(l.date),
        l.reference,
        l.description,
        l.debit == 0 ? '' : fmtMoney(l.debit),
        l.credit == 0 ? '' : fmtMoney(l.credit),
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

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (ctx) =>
          _header(repo, 'PROJECT STATEMENT', 'As of ${fmtDate(st.to)}'),
      footer: (ctx) => _footer(ctx, repo),
      build: (ctx) => [
        _partyBlock('Prepared for', st.client, [
          _kv('Project', p.code),
          _kv('Name', p.name),
          if (p.location.isNotEmpty) _kv('Location', p.location),
          _kv('Phase', repo.stage(p.stageId)?.name ?? '—'),
          _kv('Currency', 'USD'),
        ]),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _tile('Contract value', fmtMoney(ps.contractValue)),
            _tile('Invoiced', fmtMoney(st.invoiced)),
            _tile('Received', fmtMoney(st.received)),
            if (st.advances > 0.005) ...[
              _tile('Advances held', fmtMoney(st.advances)),
              _tile(
                'Due on invoices',
                fmtMoney(st.dueOnInvoices),
                strong: true,
              ),
            ] else ...[
              _tile('Billed', _pct(ps.billedPercent)),
              st.closing < -0.005
                  ? _tile('Credit balance', fmtMoney(-st.closing), strong: true)
                  : _tile('Balance due', fmtMoney(st.closing), strong: true),
            ],
          ],
        ),
        pw.SizedBox(height: 18),
        _label('1 · By phase'),
        pw.SizedBox(height: 5),
        _table(
          ['Phase', 'Tasks done', 'Invoiced', 'Received', 'Balance'],
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
                  pw.Text(
                    ph.name,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  for (final t in ph.tasks)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 60,
                            child: pw.Text(
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
                            child: pw.Text(
                              t.title,
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ),
                          pw.Text(
                            t.dueDate == null ? '' : fmtDate(t.dueDate),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final o in ph.invoices)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 2),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 60,
                            child: pw.Text(
                              o.invoice.number,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              o.invoice.title,
                              style: const pw.TextStyle(fontSize: 8.5),
                            ),
                          ),
                          pw.Text(
                            '${fmtMoney(o.invoice.total)} · paid '
                            '${fmtMoney(o.paid)}',
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
          _label('2 · Payment schedule'),
          pw.SizedBox(height: 5),
          _table(
            [
              'Instalment',
              'Due',
              'Share',
              'Value',
              'Invoice',
              'Received',
              'Remaining',
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
            '${scheduleRows.isEmpty ? 2 : 3} · By trade and item '
            '(before VAT, fee included)',
          ),
          pw.SizedBox(height: 5),
          _table(
            ['#', 'Item', 'Unit', 'Contract', 'Invoiced', 'Billed'],
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
          '${2 + (scheduleRows.isEmpty ? 0 : 1) + (ps.layers.isEmpty ? 0 : 1)}'
          ' · Account movements',
        ),
        pw.SizedBox(height: 5),
        _table(
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
          boldRows: {moves.length - 1},
          softRows: {moves.length - 1},
        ),
        pw.SizedBox(height: 18),
        if (info['bank']?.isNotEmpty ?? false) ...[
          _label('Bank details'),
          pw.SizedBox(height: 3),
          pw.Text(info['bank']!, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          st.advances > 0.005
              ? 'Due on issued invoices: ${fmtMoney(st.dueOnInvoices)}. '
                    'Advances of ${fmtMoney(st.advances)} are held on this '
                    'project: an advance on a payment term is set against '
                    'that term\'s invoice, money on account against the '
                    'next invoices. '
                    'Net account balance: '
                    '${st.closing < 0 ? 'credit ' : ''}'
                    '${fmtMoney(st.closing.abs())}. Please report any '
                    'difference within 15 days of this statement.'
              : st.closing > 0.005
              ? 'Balance due: ${fmtMoney(st.closing)}. Please report any '
                    'difference within 15 days of this statement.'
              : st.closing < -0.005
              ? 'The project account is in credit by '
                    '${fmtMoney(-st.closing)}.'
              : 'The project account is fully settled. Thank you.',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
        pw.SizedBox(height: 30),
        _signatures(repo, 'Client confirmation'),
      ],
    ),
  );
  return pdf.save();
}

String _taskState(TaskStatus s) => switch (s) {
  TaskStatus.done => 'Done',
  TaskStatus.inProgress => 'In progress',
  _ => 'To do',
};

Future<void> shareProjectStatementPdf(
  Repository repo,
  ProjectStatement ps,
) async {
  final bytes = await buildProjectStatementPdf(repo, ps);
  await Printing.sharePdf(
    bytes: bytes,
    filename:
        'Statement-${ps.project.code}-${ps.account.to.toIso8601String().substring(0, 10)}.pdf',
  );
}
