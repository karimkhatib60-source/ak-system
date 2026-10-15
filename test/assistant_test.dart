import 'dart:convert';

import 'package:ak_system/ai/assistant.dart';
import 'package:ak_system/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  test('runs the tools Claude asks for, then shows its answer', () async {
    final repo = await memoryRepo(TestClock(DateTime(2026, 10, 14, 9)));
    final requests = <Map<String, Object?>>[];
    var step = 0;
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, Object?>;
      requests.add(body);
      expect(req.headers['x-api-key'], 'sk-test');
      expect(body['model'], 'claude-opus-5-5');
      step++;
      Map<String, Object?> reply;
      if (step == 1) {
        reply = {
          'stop_reason': 'tool_use',
          'content': [
            {
              'type': 'tool_use',
              'id': 't1',
              'name': 'create_client',
              'input': {'name': 'Nadim Haddad', 'phone': '+961 3 000000'},
            },
          ],
        };
      } else if (step == 2) {
        final result = (body['messages'] as List).last['content'][0];
        final clientId = (result['content'] as String).split(' ').last;
        reply = {
          'stop_reason': 'tool_use',
          'content': [
            {
              'type': 'tool_use',
              'id': 't2',
              'name': 'save_project',
              'input': {
                'name': 'Villa Byblos',
                'client_id': clientId,
                'service': 'contracting',
                'area_sqm': 450,
                'due_date': '2027-03-31',
              },
            },
          ],
        };
      } else {
        reply = {
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': 'Done. What is the site location?'},
          ],
        };
      }
      return http.Response(jsonEncode(reply), 200);
    });

    final ai = Assistant(repo, client: client);
    await ai.setKey('sk-test');
    await ai.send('New villa for Nadim in Byblos, 450 m2, contracting');

    expect(repo.clients.single.name, 'Nadim Haddad');
    final p = repo.projects.single;
    expect(p.name, 'Villa Byblos');
    expect(p.service, ServiceType.contracting);
    expect(p.areaSqm, 450);
    expect(p.dueDate, DateTime(2027, 3, 31));
    expect(repo.stage(p.stageId)!.service, ServiceType.contracting);
    expect(ai.lines.last.text, 'Done. What is the site location?');
    expect(ai.lines.last.actions.map((a) => a.label), [
      'Added client Nadim Haddad',
      'Created project AK-26-001 Villa Byblos',
    ]);
    // The office data reaches Claude in the system prompt.
    expect(requests.last['system'] as String, contains('Villa Byblos'));
  });

  test('a refused key gives a plain message and no partial turn', () async {
    final repo = await memoryRepo(TestClock(DateTime(2026, 10, 14, 9)));
    final ai = Assistant(
      repo,
      client: MockClient(
        (_) async => http.Response('{"error":{"message":"bad key"}}', 401),
      ),
    );
    await ai.setKey('sk-bad');
    await ai.send('hello');
    expect(ai.lines.last.text, contains('key was refused'));
    expect(ai.busy, isFalse);
  });
}
