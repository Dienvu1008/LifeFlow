// P04b T13: an in-memory SpaceService + SharingService + space sync for the
// widget tests of the sharing UI. Records every call in [calls].
import 'package:application/application.dart';
import 'package:foundation/foundation.dart' show Version;

class FakeSpaces implements SpaceService, SharingService, SyncRunner {
  FakeSpaces({List<SpaceView>? spaces, this.me = 'acc-me'})
      : list = spaces ?? [const SpaceView(id: 'personal', shared: false, isShown: true)];

  List<SpaceView> list;
  final String me;
  final calls = <String>[];
  var memberLists = <String, List<SpaceMemberView>>{};
  var names = <String, Map<String, String>>{};
  var rules = <String, SpaceRules>{};
  var notices = <RulesNotice>[];
  var invitationsOpen = <RemoteInvitation>[];

  /// What peek/join answer.
  InvitationPreview? invitation;

  /// What previewMove answers.
  MovePreview? preview;

  /// A problem the next sharing call reports.
  SharingProblem? nextProblem;

  SharingResult _done(String call, {String? spaceId, InvitationToGive? invitation, InvitationPreview? preview}) {
    calls.add(call);
    final p = nextProblem;
    nextProblem = null;
    if (p != null) return SharingResult.failed(p);
    return SharingResult(spaceId: spaceId, invitation: invitation, preview: preview);
  }

  // --- SpaceService ---------------------------------------------------------
  @override
  Future<List<SpaceView>> spaces() async => list;

  @override
  Future<CommandResult> show(String spaceId) async {
    calls.add('show:$spaceId');
    list = [
      for (final s in list)
        SpaceView(
          id: s.id,
          shared: s.shared,
          isShown: s.id == spaceId,
          name: s.name,
          role: s.role,
          members: s.members,
          left: s.left,
          rulesChanged: s.rulesChanged,
        ),
    ];
    return CommandOk(spaceId, Version.initial, const []);
  }

  // --- SyncRunner -------------------------------------------------------------
  @override
  Future<SyncStatus> status() async => const SyncStatus(on: true);
  @override
  Stream<SyncStatus> watchStatus() => Stream.value(const SyncStatus(on: true));
  @override
  Future<SyncReport> syncNow() async {
    calls.add('spaceSync');
    return SyncReport(SyncOutcome.upToDate);
  }

  // --- SharingService -------------------------------------------------------
  @override
  Future<SharingResult> createSpace(String name) async {
    final r = _done('create:$name', spaceId: 'space-new');
    if (r.ok) {
      list = [
        for (final s in list)
          SpaceView(id: s.id, shared: s.shared, isShown: false, name: s.name, role: s.role, members: s.members),
        SpaceView(id: 'space-new', shared: true, isShown: true, name: name, role: SpaceRole.owner, members: 1),
      ];
    }
    return r;
  }

  @override
  Future<SharingResult> renameSpace(String spaceId, String name) async => _done('rename:$spaceId:$name');
  @override
  Future<MovePreview> previewMove(String kind, String id, String to) async {
    calls.add('preview:$kind:$id:$to');
    return preview ??
        MovePreview(
            kind: kind, id: id, to: to, counts: const {'task': 1}, titles: const ['A task'], hasNotes: false,
            hasDates: false, confirmation: const ['task:t:1']);
  }

  @override
  Future<SharingResult> move(MovePreview preview) async => _done('move:${preview.kind}:${preview.id}:${preview.to}');
  @override
  Future<SharingResult> invite(String spaceId, SpaceRole role, InviteKind kind) async => _done('invite:$spaceId:${role.name}:${kind.name}',
      invitation: InvitationToGive(
          code: 'ABCDEFGHJKLMNPQRSTUVWXYZ23',
          grouped: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ2-3',
          link: 'lifeflow://join/ABCDEFGHJKLMNPQRSTUVWXYZ23',
          kind: kind,
          role: role));
  @override
  Future<List<RemoteInvitation>> invitations(String spaceId) async => invitationsOpen;
  @override
  Future<SharingResult> cancelInvitation(String spaceId, String codeHash) async => _done('cancel:$codeHash');
  @override
  Future<SharingResult> peek(String text) async {
    final i = invitation;
    if (i == null) return const SharingResult.failed(SharingProblem.noSuchInvitation);
    return _done('peek:$text', preview: i, spaceId: i.workspaceId);
  }

  @override
  Future<SharingResult> join(String text) async => _done('join:$text', preview: invitation, spaceId: invitation?.workspaceId);
  @override
  Future<List<SpaceMemberView>> members(String spaceId) async => memberLists[spaceId] ?? const [];
  @override
  Future<SharingResult> approve(String spaceId, String accountId) async => _done('approve:$accountId');
  @override
  Future<SharingResult> removeMember(String spaceId, String accountId) async => _done('remove:$accountId');
  @override
  Future<SharingResult> leave(String spaceId) async => _done('leave:$spaceId');
  @override
  Future<SharingResult> setRole(String spaceId, String accountId, SpaceRole role) async => _done('role:$accountId:${role.name}');
  @override
  Future<SharingResult> handOver(String spaceId, String accountId) async => _done('handOver:$accountId');
  @override
  Future<SharingResult> setRules(String spaceId, SpaceRules r) async {
    final res = _done('rules:${r.leave.name}:${r.export.name}:${r.inviteDefault.name}');
    if (res.ok) rules[spaceId] = r;
    return res;
  }

  @override
  Future<SharingResult> deleteSpace(String spaceId) async => _done('delete:$spaceId');
  @override
  Future<SharingResult> assign(String taskId, String? accountId) async => _done('assign:$taskId:$accountId');
  @override
  Future<List<RulesNotice>> rulesNotices() async => notices;
  @override
  Future<void> rulesSeen(String spaceId) async => calls.add('rulesSeen:$spaceId');
  @override
  Future<(ExportFile?, SharingProblem?)> exportSpace(String spaceId) async {
    calls.add('export:$spaceId');
    return (const ExportFile(suggestedName: 'lifeflow-space.json', contents: '{}', taskCount: 0), null);
  }

  @override
  Future<SharingResult> forgetSpace(String spaceId) async => _done('forget:$spaceId');
  @override
  Future<SharingResult> setMyName(String spaceId, String name) async => _done('myName:$name');
  @override
  Future<Map<String, String>> memberNames(String spaceId) async => names[spaceId] ?? const {};
  @override
  Future<String?> myAccountId() async => me;
  @override
  Future<SpaceRules> rulesOf(String spaceId) async => rules[spaceId] ?? const SpaceRules();
}

const family = SpaceView(id: 'fam', shared: true, isShown: false, name: 'Family', role: SpaceRole.owner, members: 2);
const personalShown = SpaceView(id: 'personal', shared: false, isShown: true);
