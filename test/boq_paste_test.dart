import 'package:ak_system/data/boq_library.dart';
import 'package:ak_system/data/boq_paste.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Excel rows with item numbers and section headers', () {
    final items = parseBoq(
      'No.\tDescription\tUnit\tQty\tRate\tAmount\n'
      '1\tMasonry\n'
      '1.1\tBlock wall 20 cm\tm²\t120\t18\t2,160\n'
      '1.2\tBlock wall 10 cm\tm²\t85\t\$14\n'
      '\n'
      '2\tPainting\n'
      '2.1\tEmulsion paint to walls\tm²\t640\t6.5\n',
    );
    expect(items, hasLength(3));
    expect(items[0].section, 'Masonry');
    expect(items[0].description, 'Block wall 20 cm');
    expect(items[0].unit, 'm²');
    expect(items[0].quantity, 120);
    expect(items[0].rate, 18);
    expect(items[1].rate, 14);
    expect(items[2].section, 'Painting');
    expect(items[2].amount, closeTo(4160, 1e-9));
  });

  test('bar separated lines and a markdown table', () {
    final items = parseBoq(
      'Demolition works:\n'
      '| Item | Description | Unit | Qty | Rate |\n'
      '|---|---|---|---|---|\n'
      '| 1 | Remove floor tiles | m² | 90 | 4 |\n'
      'Mobilization | lump sum\n',
    );
    expect(items, hasLength(2));
    expect(items[0].section, 'Demolition works');
    expect(items[0].quantity, 90);
    expect(items[1].unit, 'lump sum');
    expect(items[1].quantity, 1);
    expect(items[1].rate, 0);
  });

  test('the library has units for every item', () {
    expect(boqLibrary.length, greaterThan(25));
    expect(boqLibrary.expand((t) => t.items).length, greaterThan(300));
    for (final t in boqLibrary) {
      for (final i in t.items) {
        expect(i.unit, isNotEmpty, reason: i.description);
      }
    }
  });
}
