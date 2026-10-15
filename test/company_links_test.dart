import 'package:ak_system/data/company_links.dart';
import 'package:ak_system/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AK defaults give website, phone, Instagram and Facebook links', () {
    final links = companyLinks(companyInfoDefaults);
    expect(links.map((l) => l.kind), [
      'website',
      'phone',
      'instagram',
      'facebook',
    ]);
    expect(links[0].url, 'https://www.ak-dac.com');
    expect(links[1].url, 'tel:+96179180650');
    expect(links[2].display, '@ak.designconstruction');
    expect(links[2].url, 'https://www.instagram.com/ak.designconstruction');
  });

  test('a separate WhatsApp number and a pasted Instagram URL', () {
    final links = companyLinks({
      'phone': '01 234 567',
      'whatsapp': '+961 70 111 222',
      'instagram': 'https://instagram.com/ak.designconstruction/',
    });
    expect(links[1].url, 'https://wa.me/96170111222');
    expect(links[2].display, '@ak.designconstruction');
  });
}
