/// One way to reach the company, with the text to show and where it goes.
class CompanyLink {
  const CompanyLink(this.kind, this.display, this.url);

  /// website, phone, whatsapp, email, instagram, facebook or linkedin.
  final String kind;
  final String display;
  final String url;
}

/// The company's contact and social links, in the order they are printed.
List<CompanyLink> companyLinks(Map<String, String> info) {
  String v(String k) => (info[k] ?? '').trim();
  String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  String web(String s) => s.startsWith('http') ? s : 'https://$s';
  final out = <CompanyLink>[];
  if (v('website').isNotEmpty) {
    out.add(
      CompanyLink(
        'website',
        v('website').replaceFirst(RegExp(r'^https?://'), ''),
        web(v('website')),
      ),
    );
  }
  if (v('phone').isNotEmpty) {
    out.add(CompanyLink('phone', v('phone'), 'tel:+${digits(v('phone'))}'));
  }
  if (v('whatsapp').isNotEmpty && digits(v('whatsapp')) != digits(v('phone'))) {
    out.add(
      CompanyLink(
        'whatsapp',
        'WhatsApp ${v('whatsapp')}',
        'https://wa.me/${digits(v('whatsapp'))}',
      ),
    );
  }
  if (v('email').isNotEmpty) {
    out.add(CompanyLink('email', v('email'), 'mailto:${v('email')}'));
  }
  if (v('instagram').isNotEmpty) {
    final s = v('instagram');
    final handle = s.startsWith('http')
        ? s.split('/').where((p) => p.isNotEmpty).last
        : s.replaceFirst('@', '');
    out.add(
      CompanyLink('instagram', '@$handle', 'https://www.instagram.com/$handle'),
    );
  }
  if (v('facebook').isNotEmpty) {
    out.add(CompanyLink('facebook', 'Facebook', web(v('facebook'))));
  }
  if (v('linkedin').isNotEmpty) {
    out.add(CompanyLink('linkedin', 'LinkedIn', web(v('linkedin'))));
  }
  return out;
}
