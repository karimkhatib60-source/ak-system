import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models.dart';
import '../data/repository.dart';
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
      header: (ctx) => pw.Column(
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
                    isInvoice ? 'INVOICE' : 'QUOTATION',
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
      ),
      footer: (ctx) => pw.Column(
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
      ),
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
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Description', 'Qty', 'Unit', 'Rate', 'Amount'],
          data: [
            for (var i = 0; i < doc.items.length; i++)
              [
                '${i + 1}',
                doc.items[i].description,
                _qty(doc.items[i].quantity),
                doc.items[i].unit,
                fmtMoney(doc.items[i].rate),
                fmtMoney(doc.items[i].amount),
              ],
          ],
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 8.5,
          ),
          headerDecoration: const pw.BoxDecoration(color: _graphite),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6)),
          ),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),
            1: const pw.FlexColumnWidth(5),
            2: const pw.FixedColumnWidth(36),
            3: const pw.FixedColumnWidth(54),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(76),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          headerAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 10),
        // Totals.
        pw.Row(
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  moneyRow('Subtotal', doc.subtotal),
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
