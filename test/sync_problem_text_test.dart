import 'package:ak_system/ui/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sync problems are told in plain words, each once, a few at most.
void main() {
  String missing(String table) =>
      "PostgrestException(message: Could not find the table 'public.$table' "
      'in the schema cache, code: PGRST205, details: Not Found, hint: null)';

  test('a database without its tables is one plain line', () {
    final error = [
      'The file "Plumbing Quotation.pdf" could not be uploaded yet; it will '
          'be tried again. (StorageException(message: Bucket not found, '
          'statusCode: 404, error: Bucket not found))',
      for (final t in ['stages', 'clients', 'projects', 'tasks', 'invoices'])
        missing(t),
      for (final t in ['stages', 'clients']) missing(t),
    ].join('\n');
    expect(
      syncProblemText(error),
      'The cloud file storage is not set up.\n'
      'The cloud database is missing its tables.',
    );
  });

  test('records this login may not change', () {
    expect(
      syncProblemText(
        'PostgrestException(message: new row violates row-level security '
        'policy for table "clients", code: 42501, details: Forbidden, '
        'hint: null)',
      ),
      'This login is not allowed to change some records.',
    );
  });

  test('only the first three different problems are listed', () {
    expect(
      syncProblemText('one\ntwo\nthree\nfour\nfive\nfour\n'),
      'one\ntwo\nthree\nand 2 more',
    );
  });

  test('nothing to say still says something', () {
    expect(syncProblemText(''), 'unknown');
    expect(syncProblemText('\n \n'), 'unknown');
  });
}
