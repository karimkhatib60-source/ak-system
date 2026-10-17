import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// How a column's cells are written and formatted.
enum XlsxType { text, money, date, number }

class XlsxColumn {
  const XlsxColumn(this.label, this.type, {this.width, this.total = true});

  final String label;
  final XlsxType type;

  /// A money column added up in the totals row; false for a running
  /// balance.
  final bool total;

  /// Width in characters; a width suited to the type when null.
  final double? width;
}

/// One sheet: an optional title line, a header row with filters, the rows
/// and an optional totals row that adds up the money columns (only the
/// rows a filter leaves visible).
class XlsxSheet {
  XlsxSheet(
    this.name, {
    required this.columns,
    required this.rows,
    this.title,
    this.totalsLabel,
    this.rtl = false,
  });

  final String name;
  final List<XlsxColumn> columns;

  /// Cells in column order: text, numbers or dates; null leaves a cell
  /// empty.
  final List<List<Object?>> rows;
  final String? title;

  /// Label of the totals row; no totals row when null.
  final String? totalsLabel;

  /// Right to left, for Arabic.
  final bool rtl;
}

/// An Excel workbook (.xlsx) holding [sheets].
Uint8List buildXlsx(
  List<XlsxSheet> sheets, {
  String title = '',
  String author = '',
  DateTime? created,
}) {
  final archive = Archive();
  void add(String name, String xml) =>
      archive.add(ArchiveFile.bytes(name, utf8.encode(xml)));
  final names = _sheetNames(sheets);
  add('[Content_Types].xml', _contentTypes(sheets.length));
  add('_rels/.rels', _rootRels);
  add('docProps/core.xml', _core(title, author, created ?? DateTime.now()));
  add('docProps/app.xml', _app);
  add('xl/workbook.xml', _workbook(sheets, names));
  add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
  add('xl/styles.xml', _styles);
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheet(sheets[i]));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Sheet names Excel accepts: at most 31 characters, none of []:*?/\ and
/// no two alike.
List<String> _sheetNames(List<XlsxSheet> sheets) {
  final used = <String>{};
  return [
    for (final s in sheets)
      () {
        var base = s.name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
        if (base.isEmpty) base = 'Sheet';
        if (base.length > 31) base = base.substring(0, 31);
        var name = base;
        for (var n = 2; used.contains(name.toLowerCase()); n++) {
          final tail = ' ($n)';
          name =
              '${base.length + tail.length > 31 ? base.substring(0, 31 - tail.length) : base}$tail';
        }
        used.add(name.toLowerCase());
        return name;
      }(),
  ];
}

/// The column letters of a zero-based index: A, B, ... Z, AA, AB, ...
String xlsxColumn(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Excel's day number of [d]: days since 30 December 1899.
double xlsxDate(DateTime d) => DateTime.utc(
  d.year,
  d.month,
  d.day,
).difference(DateTime.utc(1899, 12, 30)).inDays.toDouble();

final _invalidXml = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]');

String _esc(String s) => s
    .replaceAll(_invalidXml, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _contentTypes(int sheets) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '${[for (var i = 1; i <= sheets; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
    '</Types>';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

String _core(String title, String author, DateTime created) {
  final at = '${created.toUtc().toIso8601String().split('.').first}Z';
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_esc(title)}</dc:title><dc:creator>${_esc(author)}</dc:creator>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$at</dcterms:created>'
      '</cp:coreProperties>';
}

const _app =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
    '<Application>AK System</Application></Properties>';

String _workbook(List<XlsxSheet> sheets, List<String> names) {
  final filters = <String>[];
  for (var i = 0; i < sheets.length; i++) {
    final r = _tableRange(sheets[i]);
    if (r == null) continue;
    final quoted = "'${names[i].replaceAll("'", "''")}'";
    filters.add(
      '<definedName name="_xlnm._FilterDatabase" localSheetId="$i" hidden="1">'
      '${_esc('$quoted!${r.$1}')}</definedName>',
    );
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<bookViews><workbookView/></bookViews><sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets>'
      '${filters.isEmpty ? '' : '<definedNames>${filters.join()}</definedNames>'}'
      '</workbook>';
}

String _workbookRels(int sheets) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${[for (var i = 1; i <= sheets; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
    '<Relationship Id="rId${sheets + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

// Cell styles, by their index in cellXfs.
const _sText = 0;
const _sHeader = 1;
const _sMoney = 2;
const _sDate = 3;
const _sTotalText = 4;
const _sTotalMoney = 5;
const _sTitle = 6;
const _sNumber = 7;

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="2"><numFmt numFmtId="164" formatCode="#,##0.00"/>'
    '<numFmt numFmtId="165" formatCode="dd/mm/yyyy"/></numFmts>'
    '<fonts count="4">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="14"/><color rgb="FF14171C"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="4"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF14171C"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFEEF1F6"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top style="thin"><color rgb="FF14171C"/></top><bottom/><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="8">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
    '<xf numFmtId="164" fontId="2" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="1" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

/// Row numbers (1-based) of the header and of the first data row.
(int, int) _rowsOf(XlsxSheet s) => s.title == null ? (1, 2) : (3, 4);

/// The header and data range, for filters; null with no rows.
(String, int, int)? _tableRange(XlsxSheet s) {
  if (s.rows.isEmpty || s.columns.isEmpty) return null;
  final (header, first) = _rowsOf(s);
  final last = first + s.rows.length - 1;
  return (
    '\$A\$$header:\$${xlsxColumn(s.columns.length - 1)}\$$last',
    first,
    last,
  );
}

String _num(double v) {
  if (v.isNaN || v.isInfinite) return '0';
  final r = (v * 100).roundToDouble() / 100;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

String _cell(String ref, Object? v, XlsxType type, {bool total = false}) {
  if (v == null) {
    return total ? '<c r="$ref" s="$_sTotalText"/>' : '';
  }
  if (v is DateTime) {
    return '<c r="$ref" s="$_sDate"><v>${_num(xlsxDate(v))}</v></c>';
  }
  if (v is num) {
    final s = total
        ? _sTotalMoney
        : type == XlsxType.number
        ? _sNumber
        : _sMoney;
    return '<c r="$ref" s="$s"><v>${_num(v.toDouble())}</v></c>';
  }
  final s = total ? _sTotalText : _sText;
  return '<c r="$ref" s="$s" t="inlineStr"><is><t xml:space="preserve">'
      '${_esc('$v')}</t></is></c>';
}

double _width(XlsxColumn c) =>
    c.width ??
    switch (c.type) {
      XlsxType.money => 15,
      XlsxType.date => 12,
      XlsxType.number => 8,
      XlsxType.text => 24,
    };

String _sheet(XlsxSheet s) {
  final (header, first) = _rowsOf(s);
  final range = _tableRange(s);
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheetViews><sheetView workbookViewId="0"${s.rtl ? ' rightToLeft="1"' : ''}>'
    '<pane ySplit="$header" topLeftCell="A${header + 1}" activePane="bottomLeft" state="frozen"/>'
    '<selection pane="bottomLeft" activeCell="A${header + 1}" sqref="A${header + 1}"/>'
    '</sheetView></sheetViews>'
    '<sheetFormatPr defaultRowHeight="15"/>',
  );
  if (s.columns.isNotEmpty) {
    out.write('<cols>');
    for (var i = 0; i < s.columns.length; i++) {
      out.write(
        '<col min="${i + 1}" max="${i + 1}" width="${_width(s.columns[i])}" customWidth="1"/>',
      );
    }
    out.write('</cols>');
  }
  out.write('<sheetData>');
  if (s.title != null) {
    out.write(
      '<row r="1" ht="20" customHeight="1">'
      '<c r="A1" s="$_sTitle" t="inlineStr"><is><t xml:space="preserve">'
      '${_esc(s.title!)}</t></is></c></row>',
    );
  }
  out.write('<row r="$header">');
  for (var i = 0; i < s.columns.length; i++) {
    out.write(
      '<c r="${xlsxColumn(i)}$header" s="$_sHeader" t="inlineStr"><is><t xml:space="preserve">'
      '${_esc(s.columns[i].label)}</t></is></c>',
    );
  }
  out.write('</row>');
  for (var r = 0; r < s.rows.length; r++) {
    final n = first + r;
    out.write('<row r="$n">');
    final row = s.rows[r];
    for (var i = 0; i < s.columns.length && i < row.length; i++) {
      out.write(_cell('${xlsxColumn(i)}$n', row[i], s.columns[i].type));
    }
    out.write('</row>');
  }
  if (s.totalsLabel != null && range != null) {
    final n = range.$3 + 1;
    out.write('<row r="$n">');
    for (var i = 0; i < s.columns.length; i++) {
      final ref = '${xlsxColumn(i)}$n';
      if (i == 0) {
        out.write(_cell(ref, s.totalsLabel, XlsxType.text, total: true));
      } else if (s.columns[i].type == XlsxType.money && s.columns[i].total) {
        var sum = 0.0;
        for (final row in s.rows) {
          if (i < row.length && row[i] is num) sum += (row[i] as num);
        }
        final col = xlsxColumn(i);
        out.write(
          '<c r="$ref" s="$_sTotalMoney"><f>SUBTOTAL(109,$col${range.$2}:$col${range.$3})</f>'
          '<v>${_num(sum)}</v></c>',
        );
      } else {
        out.write('<c r="$ref" s="$_sTotalText"/>');
      }
    }
    out.write('</row>');
  }
  out.write('</sheetData>');
  if (range != null) {
    out.write('<autoFilter ref="${range.$1.replaceAll('\$', '')}"/>');
  }
  out.write(
    '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
    '<pageSetup paperSize="9" orientation="landscape"/>'
    '</worksheet>',
  );
  return out.toString();
}
