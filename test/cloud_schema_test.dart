import 'dart:io';
import 'dart:typed_data';

import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Columns of each table in supabase/schema.sql, with their type.
Map<String, Map<String, String>> cloudColumns() {
  final sql = File('supabase/schema.sql')
      .readAsStringSync()
      .replaceAll(RegExp(r'--[^\n]*'), '');
  final out = <String, Map<String, String>>{};
  for (final m in RegExp(
    r'create table if not exists (?:public\.)?(\w+)\s*\((.*?)\n\);',
    dotAll: true,
  ).allMatches(sql)) {
    final cols = out.putIfAbsent(m[1]!, () => {});
    for (final part in m[2]!.split(RegExp(r',(?![^()]*\))'))) {
      final w = part.trim().split(RegExp(r'\s+'));
      if (w.length > 1 &&
          !{'primary', 'unique', 'check', 'constraint'}.contains(w[0])) {
        cols[w[0]] = w[1];
      }
    }
  }
  for (final m in RegExp(
    r'alter table (?:public\.)?(\w+) add column if not exists (\w+) (\w+)',
  ).allMatches(sql)) {
    out.putIfAbsent(m[1]!, () => {})[m[2]!] = m[3]!;
  }
  for (final m in RegExp(
    r'alter table (?:public\.)?(\w+) alter column (\w+) type (\w+)',
  ).allMatches(sql)) {
    out[m[1]!]![m[2]!] = m[3]!;
  }
  return out;
}

/// What the app uploads for every kind of record, with optional fields
/// empty and filled, fits the cloud tables in supabase/schema.sql.
void main() {
  test(
    'every uploaded column exists in the cloud with a fitting type',
    () async {
      final repo = await memoryRepo(TestClock(DateTime(2026, 10, 18, 9)));
      final t = repo.now();
      const c = '11111111-1111-4111-8111-111111111111';
      const p = '22222222-2222-4222-8222-222222222222';
      const m = '33333333-3333-4333-8333-333333333333';
      const q = '44444444-4444-4444-8444-444444444444';
      const i = '55555555-5555-4555-8555-555555555555';
      const e = '66666666-6666-4666-8666-666666666666';
      String id(int n) =>
          '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
      final stage = repo.stagesFor(ServiceType.design).first.id;
      await repo.saveMember(
        Member(
          id: m,
          createdAt: t,
          updatedAt: t,
          name: 'Arch',
          email: 'a@x.com',
        ),
      );
      await repo.saveClient(
        Client(id: id(1), createdAt: t, updatedAt: t, name: 'Min'),
      );
      await repo.saveClient(
        Client(
          id: c,
          createdAt: t,
          updatedAt: t,
          name: 'Full',
          company: 'Co',
          phone: '+961',
          email: 'c@x.com',
          notes: 'n',
        ),
      );
      await repo.saveProject(
        Project(id: id(2), createdAt: t, updatedAt: t, name: 'Min'),
      );
      await repo.saveProject(
        Project(
          id: p,
          createdAt: t,
          updatedAt: t,
          name: 'Full',
          code: 'AK-1',
          clientId: c,
          service: ServiceType.consultancy,
          location: 'Byblos',
          abroad: true,
          stageId: stage,
          startDate: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 12, 1),
          teamIds: const [m],
          notes: 'n',
          areaSqm: 250.5,
          mapLink: 'https://maps.app.goo.gl/x',
          markupRate: 15,
        ),
      );
      await repo.saveTask(
        Task(id: id(3), createdAt: t, updatedAt: t, projectId: p, title: 'Min'),
      );
      await repo.saveTask(
        Task(
          id: id(4),
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: 'Full',
          assigneeId: m,
          dueDate: DateTime(2026, 10, 20),
          stageId: stage,
          notes: 'n',
        ),
      );
      await repo.saveDeliverable(
        Deliverable(
          id: id(5),
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: 'Min',
        ),
      );
      await repo.saveDeliverable(
        Deliverable(
          id: id(6),
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: 'Full',
          stageId: stage,
          version: 2,
          status: DeliverableStatus.approved,
          dueDate: DateTime(2026, 10, 1),
          submittedAt: t,
          approvedAt: t,
          fileLink: 'https://x',
          notes: 'n',
        ),
      );
      await repo.saveNote(
        ProjectNote(
          id: id(7),
          createdAt: t,
          updatedAt: t,
          projectId: p,
          date: t,
          text: 'Min',
        ),
      );
      await repo.saveNote(
        ProjectNote(
          id: id(8),
          createdAt: t,
          updatedAt: t,
          projectId: p,
          date: t,
          text: 'Full',
          authorId: m,
          pinned: true,
          ownerOnly: true,
        ),
      );
      await repo.saveQuotation(
        Quotation(
          id: id(9),
          createdAt: t,
          updatedAt: t,
          number: 'QT-1',
          date: t,
        ),
      );
      await repo.saveQuotation(
        Quotation(
          id: q,
          createdAt: t,
          updatedAt: t,
          number: 'QT-2',
          date: t,
          title: 'Full',
          clientId: c,
          projectId: p,
          validUntil: DateTime(2026, 11, 1),
          items: const [
            LineItem(
              description: 'Works',
              quantity: 2,
              unit: 'm2',
              rate: 50,
              section: 'A',
            ),
          ],
          discount: 5,
          markupRate: 15,
          status: QuotationStatus.accepted,
          terms: 'x',
          notes: 'n',
          paymentTerms: const [PaymentTerm(label: 'Advance', percent: 30)],
        ),
      );
      await repo.saveInvoice(
        Invoice(
          id: id(10),
          createdAt: t,
          updatedAt: t,
          number: 'INV-1',
          date: t,
        ),
      );
      await repo.saveInvoice(
        Invoice(
          id: i,
          createdAt: t,
          updatedAt: t,
          number: 'INV-2',
          date: t,
          title: 'Full',
          clientId: c,
          projectId: p,
          quotationId: q,
          stageId: stage,
          termIndex: 0,
          dueDate: DateTime(2026, 11, 1),
          items: const [LineItem(description: 'Works', rate: 100)],
          status: InvoiceStatus.sent,
          notes: 'n',
        ),
      );
      await repo.saveInvoice(
        Invoice(
          id: id(11),
          createdAt: t,
          updatedAt: t,
          number: 'INV-3',
          date: t,
          clientId: c,
          projectId: p,
          extra: true,
        ),
      );
      await repo.savePayment(
        Payment(
          id: id(12),
          createdAt: t,
          updatedAt: t,
          date: t,
          amount: 100,
          clientId: c,
          projectId: p,
          number: 'RC-1',
        ),
      );
      await repo.savePayment(
        Payment(
          id: id(13),
          createdAt: t,
          updatedAt: t,
          date: t,
          amount: 111,
          invoiceId: i,
          reference: 'TT',
          number: 'RC-2',
          clientId: c,
          projectId: p,
          quotationId: q,
          termIndex: 0,
          notes: 'n',
        ),
      );
      await repo.saveExpense(
        Expense(id: id(14), createdAt: t, updatedAt: t, date: t, amount: 10),
      );
      await repo.saveExpense(
        Expense(
          id: e,
          createdAt: t,
          updatedAt: t,
          date: t,
          amount: 555,
          number: 'EX-1',
          projectId: p,
          quotationId: q,
          category: ExpenseCategory.values.first,
          title: 'Stone',
          vendor: 'V',
          reference: 'R',
          items: const [LineItem(description: 'Stone', rate: 500)],
          vatRate: 11,
          paid: false,
          method: PaymentMethod.cash,
          notes: 'n',
        ),
        attach: [
          (
            Attachment(
              id: id(15),
              createdAt: t,
              updatedAt: t,
              ownerId: e,
              name: 'bill.pdf',
              mime: 'application/pdf',
              size: 3,
            ),
            Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      await repo.saveExpense(
        Expense(
          id: id(16),
          createdAt: t,
          updatedAt: t,
          date: t,
          amount: 20,
          projectId: p,
          extra: true,
        ),
      );
      final remote = FakeRemote();
      final sync = SyncService(repo.local, repo)..remote = remote;
      await sync.syncNow();
      expect(sync.lastError, isNull);
      expect(remote.tables.keys, containsAll(syncedTables.keys));
      final cloud = cloudColumns();
      for (final MapEntry(key: table, value: rows) in remote.tables.entries) {
        final cols = cloud[table];
        expect(cols, isNotNull, reason: '$table is not in schema.sql');
        for (final row in rows.values) {
          for (final MapEntry(:key, :value) in row.entries) {
            if (key == 'synced_at') continue;
            final type = cols![key];
            expect(
              type,
              isNotNull,
              reason: '$table.$key is not in schema.sql',
            );
            if (value == null) continue;
            final where = '$table.$key = $value ($type)';
            switch (type) {
              case 'uuid':
                expect(
                  value,
                  matches(RegExp(r'^[0-9a-f-]{36}$')),
                  reason: where,
                );
              case 'boolean':
                expect(value, isA<bool>(), reason: where);
              case 'integer' || 'bigint':
                expect(value, isA<int>(), reason: where);
              case 'double' || 'numeric' || 'real':
                expect(value, isA<num>(), reason: where);
            }
          }
        }
      }
    },
  );
}
