import 'dart:math';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/statement.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Random clients with several projects, contracts, instalments, receipts
/// and invoices, checked against what the payments pool promises.

/// Max flow in cents between credits and invoices that fit.
int maxFlow(List<int> credit, List<int> need, bool Function(int, int) fits) {
  final n = credit.length, m = need.length;
  // nodes: 0 source, 1..n credits, n+1..n+m invoices, n+m+1 sink
  final size = n + m + 2;
  final cap = List.generate(size, (_) => List<int>.filled(size, 0));
  for (var k = 0; k < n; k++) {
    cap[0][1 + k] = credit[k];
    for (var j = 0; j < m; j++) {
      if (fits(k, j)) cap[1 + k][n + 1 + j] = 1 << 40;
    }
  }
  for (var j = 0; j < m; j++) {
    cap[n + 1 + j][size - 1] = need[j];
  }
  var flow = 0;
  while (true) {
    final prev = List<int>.filled(size, -1);
    prev[0] = 0;
    final queue = [0];
    for (var qi = 0; qi < queue.length; qi++) {
      final u = queue[qi];
      for (var v = 0; v < size; v++) {
        if (prev[v] < 0 && cap[u][v] > 0) {
          prev[v] = u;
          queue.add(v);
        }
      }
    }
    if (prev[size - 1] < 0) break;
    var f = 1 << 50;
    for (var v = size - 1; v != 0; v = prev[v]) {
      f = min(f, cap[prev[v]][v]);
    }
    for (var v = size - 1; v != 0; v = prev[v]) {
      cap[prev[v]][v] -= f;
      cap[v][prev[v]] += f;
    }
    flow += f;
  }
  return flow;
}

void main() {
  test('random accounts: parts add up, nothing is counted twice, and no '
      'invoice stays due while credit could pay it', () async {
    final clock = TestClock(DateTime(2026, 11, 30, 9));
    final repo = await memoryRepo(clock);
    final t = repo.now();
    final projects = ['A', 'B', 'C'];
    final failures = <String>[];
    var maxFlowShort = 0;
    var doubleCount = 0;
    var iters = int.parse(
      const String.fromEnvironment('ITERS', defaultValue: '120'),
    );
    final seed0 = int.parse(
      const String.fromEnvironment('SEED', defaultValue: '2'),
    );
    final only = int.parse(
      const String.fromEnvironment('ONLY', defaultValue: '-1'),
    );
    for (var it = 0; it < iters; it++) {
      final seed = seed0 * 100000 + it;
      if (only >= 0 && seed != only) continue;
      final r = Random(seed);
      final cid = 'c$seed';
      await repo.local.save(
        'clients',
        Client(id: cid, createdAt: t, updatedAt: t, name: 'C $seed').toMap()
          ..['updated_at'] = t.toUtc().toIso8601String(),
      );
      for (final p in projects) {
        await repo.local.save(
          'projects',
          Project(
            id: '$cid-$p',
            createdAt: t,
            updatedAt: t,
            code: 'AK-$seed-$p',
            name: 'P',
            clientId: cid,
          ).toMap(),
        );
      }
      String? proj() {
        final k = r.nextInt(4);
        return k == 3 ? null : '$cid-${projects[k]}';
      }

      double amt() => r.nextBool()
          ? (r.nextInt(20) + 1) * 100.0
          : (r.nextInt(300000) + 1) / 100;
      // Quotations: one per project with 2-3 terms.
      final quotes = <Quotation>[];
      for (final p in projects) {
        if (r.nextInt(3) == 0) continue;
        final q = Quotation(
          id: '$cid-q$p',
          createdAt: t,
          updatedAt: t,
          number: 'QT-$seed-$p',
          clientId: cid,
          projectId: '$cid-$p',
          date: DateTime(2026, 10, 1),
          status: QuotationStatus.accepted,
          vatRate: r.nextBool() ? 0 : 11,
          items: [
            LineItem(description: 'W', rate: (r.nextInt(50) + 1) * 100.0),
          ],
          paymentTerms: const [
            PaymentTerm(label: 'A', percent: 30),
            PaymentTerm(label: 'B', percent: 40),
            PaymentTerm(label: 'C', percent: 30),
          ],
        );
        quotes.add(q);
        await repo.local.save('quotations', q.toMap());
      }
      final invs = <Invoice>[];
      final nInv = r.nextInt(7) + 1;
      for (var j = 0; j < nInv; j++) {
        final kind = r.nextInt(6);
        String? qid;
        int? term;
        var p = proj();
        if (kind <= 1 && quotes.isNotEmpty) {
          final q = quotes[r.nextInt(quotes.length)];
          qid = q.id;
          term = kind == 0 ? r.nextInt(3) : null;
          p = q.projectId;
        }
        final statusRoll = r.nextInt(10);
        final i = Invoice(
          id: '$cid-i$j',
          createdAt: t,
          updatedAt: t,
          number: 'INV-$seed-${j.toString().padLeft(3, '0')}',
          clientId: cid,
          projectId: p,
          quotationId: qid,
          termIndex: term,
          extra: kind == 2,
          date: DateTime(2026, 10, r.nextInt(28) + 1),
          status: statusRoll == 0
              ? InvoiceStatus.draft
              : statusRoll == 1
              ? InvoiceStatus.cancelled
              : InvoiceStatus.sent,
          vatRate: r.nextInt(4) == 0 ? 11 : 0,
          items: [LineItem(description: 'W', rate: amt())],
        );
        invs.add(i);
        await repo.local.save('invoices', i.toMap());
      }
      final nPay = r.nextInt(8) + 1;
      for (var j = 0; j < nPay; j++) {
        final kind = r.nextInt(3);
        var invoiceId = '';
        String? qid;
        int? term;
        String? p = proj();
        if (kind == 0) {
          invoiceId = invs[r.nextInt(invs.length)].id;
          p = null;
        } else if (kind == 1 && quotes.isNotEmpty) {
          final q = quotes[r.nextInt(quotes.length)];
          qid = q.id;
          term = r.nextInt(3);
          p = q.projectId;
        }
        final pay = Payment(
          id: '$cid-p$j',
          createdAt: t,
          updatedAt: t,
          number: 'RCT-$seed-${r.nextInt(1000).toString().padLeft(4, '0')}-$j',
          invoiceId: invoiceId,
          date: DateTime(2026, 10, r.nextInt(28) + 1),
          amount: amt(),
          clientId: invoiceId.isEmpty ? cid : null,
          projectId: p,
          quotationId: qid,
          termIndex: term,
        );
        await repo.local.save('payments', pay.toMap());
      }
      await repo.reload();

      final myInv = repo.invoices.where((i) => i.clientId == cid).toList();
      final myPay = repo.payments.where((p) => repo.payerOf(p) == cid).toList();
      void fail(String s) => failures.add('seed $seed: $s');
      double cents(double v) => (v * 100).round() / 100;

      void checkCut({Payment? through, DateTime? until}) {
        final tag = through == null ? 'all' : 'through ${through.id}';
        var paidTotal = 0.0;
        for (final i in myInv) {
          final s = repo.settledBy(i, until: until, through: through);
          final paid = s.fold(0.0, (a, e) => a + e.$2);
          if (paid < -0.005) fail('$tag ${i.id} paid negative $paid');
          if (paid > cents(i.total) + 0.005) {
            fail('$tag ${i.id} overpaid $paid > ${i.total}');
          }
          if (i.status != InvoiceStatus.sent && paid > 0.005) {
            fail('$tag ${i.id} not issued but paid $paid');
          }
          for (final (p, a) in s) {
            final hp = repo.homeProject(p);
            if (a < -1e-9) fail('$tag negative piece');
            if (hp != null && i.projectId != null && hp != i.projectId) {
              fail('$tag ${p.id} ($hp) paid ${i.id} (${i.projectId})');
            }
          }
          paidTotal += paid;
        }
        for (final p in myPay) {
          if (through != null &&
              p.id != through.id &&
              Repository.receiptOrder(p, through) > 0) {
            continue;
          }
          if (until != null &&
              DateTime(p.date.year, p.date.month, p.date.day).isAfter(until)) {
            continue;
          }
          final applied = repo
              .appliedTo(p, until: until, through: through)
              .fold(0.0, (a, e) => a + e.$2);
          final un = repo.unappliedOf(p, until: until, through: through);
          if (un < -0.005) fail('$tag ${p.id} negative credit $un');
          if ((applied + un - p.amount).abs() > 0.005) {
            fail('$tag ${p.id} parts $applied + $un != ${p.amount}');
          }
        }
        // Max flow.
        final credits = [
          for (final p in myPay)
            if ((through == null ||
                    p.id == through.id ||
                    Repository.receiptOrder(p, through) < 0) &&
                (until == null ||
                    !DateTime(
                      p.date.year,
                      p.date.month,
                      p.date.day,
                    ).isAfter(until)))
              p,
        ];
        final targets = [
          for (final i in myInv)
            if (i.status == InvoiceStatus.sent &&
                (until == null ||
                    !DateTime(
                      i.date.year,
                      i.date.month,
                      i.date.day,
                    ).isAfter(until)))
              i,
        ];
        final mf = maxFlow(
          [for (final p in credits) (p.amount * 100).round()],
          [for (final i in targets) (i.total * 100).round()],
          (k, j) {
            final hp = repo.homeProject(credits[k]);
            final ip = targets[j].projectId;
            return hp == null || ip == null || hp == ip;
          },
        );
        if (mf - (paidTotal * 100).round() > 1) {
          maxFlowShort++;
          fail('$tag paid ${paidTotal.toStringAsFixed(2)} but max ${mf / 100}');
        }
      }

      if (only >= 0) {
        for (final i in myInv.toList()..sort(Repository.invoiceOrder)) {
          // ignore: avoid_print
          print(
            'INV ${i.id} ${i.date.day} ${i.status.name} proj=${i.projectId} q=${i.quotationId} t=${i.termIndex} total=${i.total} paid=${repo.paidOn(i)} by=${repo.settledBy(i).map((e) => '${e.$1.id}:${e.$2}').join(',')}',
          );
        }
        for (final p in myPay.toList()..sort(Repository.receiptOrder)) {
          // ignore: avoid_print
          print(
            'PAY ${p.id} ${p.date.day} home=${repo.homeProject(p)} inv=${p.invoiceId} amt=${p.amount} un=${repo.unappliedOf(p)} applied=${repo.appliedTo(p).map((e) => '${e.$1.id}:${e.$2}').join(',')}',
          );
        }
      }
      checkCut();
      for (final p in myPay) {
        checkCut(through: p, until: p.date);
      }

      // money() per project and overall for this client.
      for (final p in [...projects.map((x) => '$cid-$x')]) {
        final m = repo.money(projectId: p);
        final lhs = m.received;
        final rhs = m.invoiced - m.outstanding + m.advances;
        // invoiced - outstanding only equals paid when nothing is overpaid.
        if ((lhs - rhs).abs() > 0.05) {
          fail('money($p) received $lhs != invoiced-outstanding+advances $rhs');
        }
      }
      // Statements.
      for (final p in [null, ...projects.map((x) => '$cid-$x')]) {
        final st = buildStatement(
          repo,
          cid,
          projectId: p,
          to: DateTime(2026, 11, 30),
        );
        final a = st.closing;
        final b = st.dueOnInvoices - st.advances;
        if ((a - b).abs() > 0.02) {
          fail('statement($p) closing $a != due-advances $b');
        }
      }
      // Double counting between terms and non-term invoices.
      var counted = 0.0;
      for (final q in repo.quotations.where((q) => q.clientId == cid)) {
        for (var k = 0; k < q.paymentTerms.length; k++) {
          final st = repo.termStatus(q, k);
          if (st.received < -0.005) fail('term negative');
          counted += st.received;
        }
      }
      for (final i in myInv) {
        if (i.termIndex == null ||
            !repo.quotations.any((q) => q.id == i.quotationId)) {
          counted += repo.paidOn(i);
          // By design: an advance on a term of a contract this invoice
          // bills also counts on the term.
          for (final (p, a) in repo.settledBy(i)) {
            if (p.onInvoice || p.quotationId == null || p.termIndex == null) {
              continue;
            }
            final q = repo.quotation(p.quotationId);
            if (q == null) continue;
            final bills =
                i.quotationId == q.id ||
                (i.quotationId == null &&
                    !i.extra &&
                    i.projectId == q.projectId);
            if (bills) counted -= a;
          }
        }
      }
      for (final p in myPay) {
        if (!(p.quotationId != null && p.termIndex != null && !p.onInvoice)) {
          counted += repo.unappliedOf(p);
        }
      }
      final total = myPay.fold(0.0, (s, p) => s + p.amount);
      if (counted > total + 0.02) {
        doubleCount++;
        failures.add('seed $seed: DOUBLE counted $counted > received $total');
      }
    }
    expect(failures.take(20).toList(), isEmpty);
    expect(maxFlowShort, 0);
    expect(doubleCount, 0);
  }, timeout: const Timeout(Duration(minutes: 9)));
}
