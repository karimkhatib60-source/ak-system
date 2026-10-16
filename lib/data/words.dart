import '../l10n/lang.dart';

const _ones = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];
const _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

String _under1000(int n) {
  final parts = <String>[];
  if (n >= 100) {
    parts.add('${_ones[n ~/ 100]} hundred');
    n %= 100;
  }
  if (n >= 20) {
    parts.add(
      n % 10 == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]}-${_ones[n % 10]}',
    );
  } else if (n > 0) {
    parts.add(_ones[n]);
  }
  return parts.join(' ');
}

String _words(int n) {
  if (n == 0) return 'zero';
  const scales = ['', ' thousand', ' million', ' billion'];
  final parts = <String>[];
  var i = 0;
  while (n > 0) {
    final chunk = n % 1000;
    if (chunk > 0) parts.insert(0, '${_under1000(chunk)}${scales[i]}');
    n ~/= 1000;
    i++;
  }
  return parts.join(' ');
}

/// "Two thousand five hundred US dollars and 50 cents", as written on
/// receipts and cheques. In Arabic, as on Lebanese receipts: "فقط ألفان
/// وخمسمئة دولار أميركي وخمسون سنتاً لا غير".
String dollarsInWords(double amount, [AppLang lang = AppLang.en]) {
  final cents = (amount * 100).round();
  final d = cents ~/ 100;
  final c = cents % 100;
  if (lang == AppLang.ar) return _arabicDollars(d, c);
  final text =
      '${_words(d)} US dollar${d == 1 ? '' : 's'}'
      '${c == 0 ? '' : ' and $c cent${c == 1 ? '' : 's'}'}';
  return text[0].toUpperCase() + text.substring(1);
}

// Arabic. Dollars and cents are masculine, so 3 to 10 take the feminine
// form of the number (ثلاثة دولارات). The counted word is plural after 3
// to 10, singular with tanween after 11 to 99 (أحد عشر دولاراً), and
// singular after hundreds and round thousands (مئة دولار، ألف دولار).

const _arOnes = [
  '',
  'واحد',
  'اثنان',
  'ثلاثة',
  'أربعة',
  'خمسة',
  'ستة',
  'سبعة',
  'ثمانية',
  'تسعة',
  'عشرة',
  'أحد عشر',
  'اثنا عشر',
  'ثلاثة عشر',
  'أربعة عشر',
  'خمسة عشر',
  'ستة عشر',
  'سبعة عشر',
  'ثمانية عشر',
  'تسعة عشر',
];
const _arTens = [
  '',
  '',
  'عشرون',
  'ثلاثون',
  'أربعون',
  'خمسون',
  'ستون',
  'سبعون',
  'ثمانون',
  'تسعون',
];
const _arHundreds = [
  '',
  'مئة',
  'مئتان',
  'ثلاثمئة',
  'أربعمئة',
  'خمسمئة',
  'ستمئة',
  'سبعمئة',
  'ثمانمئة',
  'تسعمئة',
];

/// 1 to 999, the parts joined by "و": "مئة وخمسة وعشرون". [construct]
/// writes 200 as "مئتا" for a word that follows directly ("مئتا دولار").
String _arUnder1000(int n, {bool construct = false}) {
  final parts = <String>[];
  final h = n ~/ 100;
  final r = n % 100;
  if (h > 0) parts.add(h == 2 && r == 0 && construct ? 'مئتا' : _arHundreds[h]);
  if (r >= 20) {
    final u = r % 10;
    parts.add(u == 0 ? _arTens[r ~/ 10] : '${_arOnes[u]} و${_arTens[r ~/ 10]}');
  } else if (r > 0) {
    parts.add(_arOnes[r]);
  }
  return parts.join(' و');
}

/// [n] thousands, millions or billions. [forms]: singular, dual, dual
/// before a word, plural, singular with tanween. [followed] is true when
/// the currency word comes right after ("ألفا دولار", "أحد عشر ألف دولار").
String _arScaled(int n, List<String> forms, bool followed) {
  if (n == 1) return forms[0];
  if (n == 2) return forms[followed ? 2 : 1];
  final r = n % 100;
  final words = _arUnder1000(n, construct: r == 0);
  if (r >= 3 && r <= 10) return '$words ${forms[3]}';
  if (r >= 11) return '$words ${forms[followed ? 0 : 4]}';
  return '$words ${forms[0]}';
}

const _arScales = [
  ['ألف', 'ألفان', 'ألفا', 'آلاف', 'ألفاً'],
  ['مليون', 'مليونان', 'مليونا', 'ملايين', 'مليوناً'],
  ['مليار', 'ملياران', 'مليارا', 'مليارات', 'ملياراً'],
];

/// [n] (2 or more) in words, ready for a currency word after it.
String _arNumber(int n) {
  final chunks = <int>[];
  for (var k = n; k > 0; k ~/= 1000) {
    chunks.add(k % 1000);
  }
  final units = chunks.first;
  final parts = <String>[];
  for (var i = chunks.length - 1; i >= 1; i--) {
    if (chunks[i] == 0) continue;
    // The last scale part meets the currency word when no units follow.
    final followed = units == 0 && chunks.sublist(1, i).every((c) => c == 0);
    parts.add(_arScaled(chunks[i], _arScales[i - 1], followed));
  }
  if (units > 0) parts.add(_arUnder1000(units, construct: true));
  return parts.join(' و');
}

/// [n] of a counted word: [one] for 1, [two] for 2, [plural] after 3 to
/// 10, [many] after 11 to 99, else [single] ("مئة دولار أميركي").
String _arCount(
  int n, {
  required String one,
  required String two,
  required String plural,
  required String many,
  required String single,
}) {
  if (n == 1) return one;
  if (n == 2) return two;
  final r = n % 100;
  final noun = r >= 3 && r <= 10
      ? plural
      : r >= 11
      ? many
      : single;
  return '${_arNumber(n)} $noun';
}

String _arabicDollars(int d, int c) {
  final dollars = d == 0
      ? (c == 0 ? 'صفر دولار أميركي' : '')
      : _arCount(
          d,
          one: 'دولار أميركي واحد',
          two: 'دولاران أميركيان',
          plural: 'دولارات أميركية',
          many: 'دولاراً أميركياً',
          single: 'دولار أميركي',
        );
  final cents = c == 0
      ? ''
      : _arCount(
          c,
          one: 'سنت واحد',
          two: 'سنتان',
          plural: 'سنتات',
          many: 'سنتاً',
          single: 'سنت',
        );
  final both = dollars.isEmpty
      ? cents
      : cents.isEmpty
      ? dollars
      : '$dollars و$cents';
  return 'فقط $both لا غير';
}
