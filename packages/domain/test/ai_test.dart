// P06 T1 (ADR-0080): the AI egress rule and version-bound approvals.
//   egress    the whole matrix, case by case; Restricted never reaches the
//             cloud whatever the policy and consent (GS-16, pure part);
//             with cloud off nothing goes to the cloud
//   approval  bound to the person, the exact arguments and the versions;
//             stale when any version changed or the thing is gone (GS-15,
//             pure part); key order does not matter, values do
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

const pub = DataClassification.public, per = DataClassification.personal;
const con = DataClassification.confidential, res = DataClassification.restricted;
const dev = AiEngineSite.device, cloud = AiEngineSite.cloud;
const allow = AiEgress.allow, consent = AiEgress.needsConsent, deny = AiEgress.deny;

AiEgressPolicy pol({bool cloudOn = false, bool scope = false}) =>
    AiEgressPolicy(cloudEnabled: cloudOn, scopeIncludesConfidential: scope);

final at = Instant(DateTime.utc(2026, 11, 4, 9));
const task = ResourceRef('task', 't1');
const event = ResourceRef('event', 'e1');

ProposedChange change({Map<String, Object?>? args, Map<ResourceRef, int>? versions, String id = 'c1'}) => ProposedChange(
      id: id,
      commandType: 'SetTaskSchedule',
      arguments: args ?? {'id': 't1', 'start': {'date': '2026-11-04', 'time': '14:30'}, 'minutes': 15},
      versions: versions ?? {task: 3, event: 7},
      summary: 'Gọi điện cho mẹ lúc 14:30',
    );

AiProposal proposal(List<ProposedChange> changes) =>
    AiProposal(id: 'p1', sessionId: 's1', model: 'qwen3.5-2b', createdAt: at, changes: changes);

const policy = AiPolicyContext(site: dev, model: 'qwen3.5-2b');

void main() {
  group('egress (data-classification.md §2)', () {
    test('the whole matrix, case by case', () {
      final cases = <(DataClassification, AiEngineSite, AiEgressPolicy, AiEgress)>[
        // On this device.
        (pub, dev, pol(), allow),
        (per, dev, pol(), allow),
        (con, dev, pol(), consent),
        (con, dev, pol(scope: true), allow),
        (res, dev, pol(), consent),
        (res, dev, pol(scope: true, cloudOn: true), consent),
        // In the cloud, the option off: nothing.
        (pub, cloud, pol(), deny),
        (per, cloud, pol(), deny),
        (con, cloud, pol(scope: true), deny),
        (res, cloud, pol(), deny),
        // In the cloud, the option on.
        (pub, cloud, pol(cloudOn: true), allow),
        (per, cloud, pol(cloudOn: true), allow),
        (con, cloud, pol(cloudOn: true), consent),
        (con, cloud, pol(cloudOn: true, scope: true), consent),
        (res, cloud, pol(cloudOn: true), deny),
        (res, cloud, pol(cloudOn: true, scope: true), deny),
      ];
      for (final (c, s, p, want) in cases) {
        expect(aiEgressOf(c, s, p), want, reason: '${c.name} to ${s.name}, cloud ${p.cloudEnabled}, scope ${p.scopeIncludesConfidential}');
      }
    });

    test('GS-16 (pure): Restricted is never sent to the cloud, whatever the policy and the consent', () {
      for (final cloudOn in [false, true]) {
        for (final scope in [false, true]) {
          for (final consented in [false, true]) {
            expect(aiMaySend(res, cloud, pol(cloudOn: cloudOn, scope: scope), consented: consented), isFalse);
          }
        }
      }
    });

    test('consent lets through what needs it, and only that', () {
      expect(aiMaySend(con, cloud, pol(cloudOn: true), consented: false), isFalse);
      expect(aiMaySend(con, cloud, pol(cloudOn: true), consented: true), isTrue);
      expect(aiMaySend(res, dev, pol(), consented: false), isFalse);
      expect(aiMaySend(res, dev, pol(), consented: true), isTrue);
      expect(aiMaySend(per, cloud, pol(), consented: true), isFalse, reason: 'consent does not turn the cloud on');
      expect(aiMaySend(per, dev, pol(), consented: false), isTrue);
    });
  });

  group('approvals (ADR-0012)', () {
    test('an approval holds for the same person, arguments and versions', () {
      final c = change();
      final p = proposal([c]);
      final a = approveChange(p, c, actorId: 'profile-1', at: at, policy: policy);
      expect((a.proposalId, a.changeId, a.actorId), ('p1', 'c1', 'profile-1'));
      expect(a.versions, {task: 3, event: 7});
      final now = {task: 3, event: 7};
      expect(approvalProblem(a, proposalId: 'p1', change: c, actorId: 'profile-1', current: (r) => now[r]), isNull);
    });

    test('GS-15 (pure): a thing changed or gone since the proposal makes the approval stale', () {
      final c = change();
      final a = approveChange(proposal([c]), c, actorId: 'me', at: at, policy: policy);
      ApprovalProblem? check(Map<ResourceRef, int> now) =>
          approvalProblem(a, proposalId: 'p1', change: c, actorId: 'me', current: (r) => now[r]);
      expect(check({task: 4, event: 7}), ApprovalProblem.stale, reason: 'the task changed');
      expect(check({task: 3, event: 8}), ApprovalProblem.stale, reason: 'the event changed');
      expect(check({event: 7}), ApprovalProblem.stale, reason: 'the task is gone');
      expect(check({task: 3, event: 7, const ResourceRef('task', 'other'): 1}), isNull, reason: 'other things do not matter');
    });

    test('another person, proposal or change does not use this approval', () {
      final c = change();
      final other = change(id: 'c2');
      final a = approveChange(proposal([c, other]), c, actorId: 'me', at: at, policy: policy);
      int? now(ResourceRef r) => {task: 3, event: 7}[r];
      expect(approvalProblem(a, proposalId: 'p1', change: c, actorId: 'someone', current: now), ApprovalProblem.notThisApproval);
      expect(approvalProblem(a, proposalId: 'p2', change: c, actorId: 'me', current: now), ApprovalProblem.notThisApproval);
      expect(approvalProblem(a, proposalId: 'p1', change: other, actorId: 'me', current: now), ApprovalProblem.notThisApproval);
    });

    test('what runs is what was approved: changed arguments or versions are refused', () {
      final c = change();
      final a = approveChange(proposal([c]), c, actorId: 'me', at: at, policy: policy);
      int? now(ResourceRef r) => {task: 3, event: 7}[r];
      final moved = change(args: {'id': 't1', 'start': {'date': '2026-11-04', 'time': '15:00'}, 'minutes': 15});
      expect(approvalProblem(a, proposalId: 'p1', change: moved, actorId: 'me', current: now), ApprovalProblem.argumentsChanged);
      final fewer = change(versions: {task: 3});
      expect(approvalProblem(a, proposalId: 'p1', change: fewer, actorId: 'me', current: now), ApprovalProblem.argumentsChanged);
      final reordered = change(args: {'minutes': 15, 'start': {'time': '14:30', 'date': '2026-11-04'}, 'id': 't1'});
      expect(approvalProblem(a, proposalId: 'p1', change: reordered, actorId: 'me', current: now), isNull,
          reason: 'the same arguments in another key order');
    });

    test('a change that creates something has no versions: its approval holds', () {
      final c = change(versions: {}, args: {'title': 'Đi chợ'});
      final a = approveChange(proposal([c]), c, actorId: 'me', at: at, policy: policy);
      expect(approvalProblem(a, proposalId: 'p1', change: c, actorId: 'me', current: (_) => null), isNull);
    });

    test('property: an approval holds exactly when every version it names is unchanged', () {
      final rnd = Random(6);
      for (var n = 0; n < 500; n++) {
        final refs = [for (var i = 0; i < rnd.nextInt(5); i++) ResourceRef(rnd.nextBool() ? 'task' : 'event', 'x$i')];
        final versions = {for (final r in refs) r: 1 + rnd.nextInt(5)};
        final c = change(versions: versions);
        final a = approveChange(proposal([c]), c, actorId: 'me', at: at, policy: policy);
        final now = {for (final e in versions.entries) e.key: rnd.nextInt(4) == 0 ? e.value + 1 : e.value};
        if (rnd.nextInt(6) == 0 && now.isNotEmpty) now.remove(now.keys.first);
        final same = versions.entries.every((e) => now[e.key] == e.value);
        expect(approvalProblem(a, proposalId: 'p1', change: c, actorId: 'me', current: (r) => now[r]) == null, same);
      }
    });

    test('a proposal names each change once; an approval is only for its own proposal\'s change', () {
      expect(() => proposal([change(), change()]), throwsArgumentError);
      final p = proposal([change()]);
      expect(() => approveChange(p, change(), actorId: 'me', at: at, policy: policy), throwsArgumentError,
          reason: 'an equal change, but not this proposal\'s');
    });

    test('canonical arguments: keys sorted at every level; list order kept; values kept', () {
      expect(canonicalArguments({'b': 1, 'a': {'d': 2, 'c': [3, 1]}}), '{"a":{"c":[3,1],"d":2},"b":1}');
      expect(canonicalArguments({'a': [1, 3]}), isNot(canonicalArguments({'a': [3, 1]})));
      expect(canonicalArguments({'title': 'Gọi mẹ'}), '{"title":"Gọi mẹ"}');
    });
  });
}
