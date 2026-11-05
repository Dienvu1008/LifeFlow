// P01 T4 (domain): guest-first bind-or-new rule (ADR-0008). Pure decisions,
// no DB. Invariants: LF-INV-ID-001 (bind never re-keys), LF-INV-ID-002
// (declined move -> a new isolated profile), LF-INV-WA-001 (one workspace).
import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  const binder = ProfileBinder();

  AccountBinding bind() => AccountBinding(
        accountId: 'acc-123',
        provider: AccountProvider.github,
        boundAt: Instant.now(),
      );

  LocalProfile guest({AccountBinding? binding}) => LocalProfile(
        profileId: const EntityId('p1'),
        activeWorkspaceId: const EntityId('w1'),
        displayName: 'Guest',
        binding: binding,
      );

  group('bind-or-new rule (ADR-0008)', () {
    test('empty profile binds in place without asking (LF-INV-ID-001)', () {
      final d = binder.decide(
        profile: guest(),
        hasData: false,
        moveData: false, // ignored when empty
        binding: bind(),
      );
      expect(d, isA<BindInPlace>());
    });

    test('profile with data + move=true binds in place, keeps ids (ID-001)', () {
      final d = binder.decide(
        profile: guest(),
        hasData: true,
        moveData: true,
        binding: bind(),
      );
      expect(d, isA<BindInPlace>());
      // boundTo preserves every id (no re-key).
      final p = guest().boundTo((d as BindInPlace).binding);
      expect(p.profileId, const EntityId('p1'));
      expect(p.activeWorkspaceId, const EntityId('w1'));
      expect(p.isBound, isTrue);
    });

    test('profile with data + move=false -> a NEW isolated profile (ID-002)', () {
      final d = binder.decide(
        profile: guest(),
        hasData: true,
        moveData: false,
        binding: bind(),
        newProfileId: const EntityId('p2'),
        newWorkspaceId: const EntityId('w2'),
      );
      expect(d, isA<CreateNewBoundProfile>());
      final n = d as CreateNewBoundProfile;
      // Fresh ids, different from the original -> isolation.
      expect(n.newProfileId, const EntityId('p2'));
      expect(n.newWorkspaceId, const EntityId('w2'));
      expect(n.newProfileId, isNot(const EntityId('p1')));
    });

    test('new-profile ids are generated when not supplied', () {
      final d = binder.decide(
        profile: guest(),
        hasData: true,
        moveData: false,
        binding: bind(),
      ) as CreateNewBoundProfile;
      expect(d.newProfileId.value, isNotEmpty);
      expect(d.newWorkspaceId.value, isNotEmpty);
      expect(d.newProfileId.value, isNot(d.newWorkspaceId.value));
    });

    test('binding an already-bound profile is rejected (one account per profile)',
        () {
      expect(
        () => binder.decide(
          profile: guest(binding: bind()),
          hasData: true,
          moveData: true,
          binding: bind(),
        ),
        throwsArgumentError,
      );
    });
  });

  test('boundTo does not change profile/workspace ids (LF-INV-ID-001)', () {
    final before = guest();
    final after = before.boundTo(bind());
    expect(after.profileId, before.profileId);
    expect(after.activeWorkspaceId, before.activeWorkspaceId);
    expect(before.isBound, isFalse);
    expect(after.isBound, isTrue);
  });
}
