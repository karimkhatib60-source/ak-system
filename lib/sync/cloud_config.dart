import 'package:flutter/foundation.dart';

/// The company's cloud database, built into the apps so each person only
/// signs in. The publishable key is made to ship inside apps: what each
/// login may read or change is decided by the database rules in
/// supabase/schema.sql. A build can use another database with
/// --dart-define=AK_CLOUD_URL=... --dart-define=AK_CLOUD_KEY=...
const _url = String.fromEnvironment(
  'AK_CLOUD_URL',
  defaultValue: 'https://nepevsjmjcvyeanmzmce.supabase.co',
);
const _key = String.fromEnvironment(
  'AK_CLOUD_KEY',
  defaultValue: 'sb_publishable_BCId6z5c-ZzVzaM_lkmY5g_SElWkfhE',
);

typedef CloudAddress = ({String url, String key});

/// Null in the web preview, which runs inside a page that may not be
/// allowed to reach the cloud, and in builds without an address.
CloudAddress? get builtInCloud =>
    kIsWeb || !_url.startsWith('https://') ? null : (url: _url, key: _key);
