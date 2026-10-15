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
/// receipts and cheques.
String dollarsInWords(double amount) {
  final cents = (amount * 100).round();
  final d = cents ~/ 100;
  final c = cents % 100;
  final text =
      '${_words(d)} US dollar${d == 1 ? '' : 's'}'
      '${c == 0 ? '' : ' and $c cent${c == 1 ? '' : 's'}'}';
  return text[0].toUpperCase() + text.substring(1);
}
