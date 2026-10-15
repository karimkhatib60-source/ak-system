import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';

/// Google Maps address for a project: its saved map link, or a search for
/// its location.
Uri? mapUri(Project p) {
  final link = p.mapLink.trim();
  if (link.isNotEmpty) {
    return Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
  }
  if (p.location.trim().isEmpty) return null;
  return mapSearchUri(p.location);
}

Uri mapSearchUri(String query) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': query.trim(),
});

Future<void> openUri(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
