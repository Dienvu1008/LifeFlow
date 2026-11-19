// P04b T8 (ADR-0060; p04b-plan.md B1): the spaces of the active profile, as
// the app sees them: its personal workspace and the shared spaces its account
// belongs to. One is shown at a time; every view shows that one.
// P04b T12 (ADR-0064): sharing them: create, name, move in and out, invite,
// join, approve, remove, leave, roles, hand over, the rules, assign, export.
import 'app_services.dart' show ExportFile;
import 'command.dart' show CommandResult;
import 'remote_spaces.dart';

enum SpaceRole { owner, editor, viewer }

/// What is left of a space this account is no longer in (B8).
enum SpaceLeft {
  /// Still a member.
  no,

  /// A read-only copy of what there was (leaving rule (c)).
  readOnly,

  /// Hidden; it may be exported once, then it goes (leaving rule (b)).
  exportFirst,
}

class SpaceView {
  const SpaceView({
    required this.id,
    required this.shared,
    required this.isShown,
    this.name,
    this.role,
    this.members = 0,
    this.left = SpaceLeft.no,
    this.rulesChanged = false,
  });
  final String id;

  /// False for the personal workspace.
  final bool shared;
  final bool isShown;

  /// A shared space's name; null for the personal workspace.
  final String? name;

  /// The user's role in a shared space; null for the personal workspace.
  final SpaceRole? role;

  /// Active members of a shared space.
  final int members;
  final SpaceLeft left;

  /// The owner changed the rules since this device last showed them
  /// (LF-INV-SHARE-005).
  final bool rulesChanged;
}

abstract interface class SpaceService {
  /// The personal workspace first, then the shared spaces by name.
  Future<List<SpaceView>> spaces();

  /// Shows [spaceId]; every view follows (the UI reads them again).
  Future<CommandResult> show(String spaceId);
}

/// Why a sharing action did not happen. Safe to show.
enum SharingProblem {
  /// Not signed in to an account (B5).
  notSignedIn,

  /// Sync of the personal data is not on (B5): it carries the space keys.
  syncOff,
  offline,

  /// The role does not allow it (B4), or the space is not this account's.
  notAllowed,
  noSuchInvitation,
  alreadyMember,
  spaceFull,
  tooManySpaces,
  ownerMustHandOver,

  /// What would move changed since it was shown: look again (PRIV-002).
  changedSinceShown,

  /// It cannot move (Restricted data, a tracked task, a subtask alone).
  cannotMove,

  /// The export rule does not allow it (B14).
  exportNotAllowed,
  failed,
}

class SharingResult {
  const SharingResult({this.problem, this.detail = '', this.spaceId, this.invitation, this.preview});
  const SharingResult.failed(SharingProblem this.problem, [this.detail = ''])
      : spaceId = null,
        invitation = null,
        preview = null;
  final SharingProblem? problem;

  /// For logs; never content or a key.
  final String detail;
  bool get ok => problem == null;

  /// The space made or joined.
  final String? spaceId;

  /// The invitation made.
  final InvitationToGive? invitation;

  /// For join: what the invitation was for.
  final InvitationPreview? preview;
}

/// An invitation to give to someone (B6): the code, grouped for reading,
/// and as a lifeflow://join/ link (also for a QR code).
class InvitationToGive {
  const InvitationToGive({required this.code, required this.grouped, required this.link, required this.kind, required this.role});
  final String code;
  final String grouped;
  final String link;
  final InviteKind kind;
  final SpaceRole role;
}

/// What a move would make visible (B3), shown before it is confirmed.
class MovePreview {
  const MovePreview({
    required this.kind,
    required this.id,
    required this.to,
    required this.counts,
    required this.titles,
    required this.hasNotes,
    required this.hasDates,
    required this.confirmation,
    this.blocker,
  });

  /// The item: 'taskList', 'task', 'event', 'calendar', 'goal' or (P05a)
  /// 'document'. A document moves with its subdocuments and its whole
  /// history: `counts['documentRevision']` earlier versions (C8).
  final String kind;
  final String id;

  /// Where it goes.
  final String to;

  /// How many records of each kind move with it.
  final Map<String, int> counts;

  /// The titles that become visible (lists, tasks, events, calendars, goals,
  /// milestones), at most 50.
  final List<String> titles;
  final bool hasNotes;
  final bool hasDates;

  /// What is confirmed: if any of it changed, nothing moves.
  final List<String> confirmation;

  /// Why it cannot move, or null.
  final String? blocker;
}

/// A space whose rules changed since this device last showed them.
class RulesNotice {
  const RulesNotice({required this.spaceId, required this.name, required this.rules, required this.changedAt});
  final String spaceId;
  final String? name;
  final SpaceRules rules;
  final DateTime changedAt;
}

abstract interface class SharingService {
  /// A new space owned by the account, named [name]; shown afterwards.
  Future<SharingResult> createSpace(String name);

  /// The owner names the space again.
  Future<SharingResult> renameSpace(String spaceId, String name);

  /// What moving the item to [to] (a shared space, or the personal
  /// workspace) would make visible, and whether it can move.
  Future<MovePreview> previewMove(String kind, String id, String to);

  /// Moves what [preview] showed, if nothing changed since.
  Future<SharingResult> move(MovePreview preview);

  Future<SharingResult> invite(String spaceId, SpaceRole role, InviteKind kind);
  Future<List<RemoteInvitation>> invitations(String spaceId);
  Future<SharingResult> cancelInvitation(String spaceId, String codeHash);

  /// What a typed, pasted or linked code is an invitation to (the rules are
  /// shown before joining, SHARE-005); null when it is not a code.
  Future<SharingResult> peek(String text);

  /// Joins with a code; "approve" invitations wait for the owner. [name] is
  /// how the others will know this person (sealed for the owner, ADR-0065);
  /// without one, the profile's name.
  Future<SharingResult> join(String text, {String? name});

  /// The space's members, as the server says (the owner sees who waits),
  /// with their names.
  Future<List<SpaceMemberView>> members(String spaceId);
  Future<SharingResult> approve(String spaceId, String accountId);

  /// Removes a member (or turns down someone waiting); the space's key is
  /// rotated so they cannot read anything new (B8).
  Future<SharingResult> removeMember(String spaceId, String accountId);

  /// Leaves the space; what stays here is its leaving rule's (B8).
  Future<SharingResult> leave(String spaceId);
  Future<SharingResult> setRole(String spaceId, String accountId, SpaceRole role);
  Future<SharingResult> handOver(String spaceId, String accountId);
  Future<SharingResult> setRules(String spaceId, SpaceRules rules);

  /// Deletes the space for everyone (the owner).
  Future<SharingResult> deleteSpace(String spaceId);

  /// Assigns a task of a shared space to a member, or to nobody (B9).
  Future<SharingResult> assign(String taskId, String? accountId);

  /// Spaces whose rules changed since last shown (SHARE-005).
  Future<List<RulesNotice>> rulesNotices();
  Future<void> rulesSeen(String spaceId);

  /// A readable copy of a space's data, if its export rule allows it (B14),
  /// or once after leaving under rule (b).
  Future<(ExportFile?, SharingProblem?)> exportSpace(String spaceId);

  /// Lets a left space go from this device (its copy, B8).
  Future<SharingResult> forgetSpace(String spaceId);

  /// P04b T13 (ADR-0065): this account's name in the space, as the others
  /// see it.
  Future<SharingResult> setMyName(String spaceId, String name);

  /// The names of the space's members known here, by account id.
  Future<Map<String, String>> memberNames(String spaceId);

  /// This profile's account id (to find "me" among members and assignees).
  Future<String?> myAccountId();

  /// The space's rules as last known on this device.
  Future<SpaceRules> rulesOf(String spaceId);
}

/// A member of a space as the app shows them (P04b T13).
class SpaceMemberView {
  const SpaceMemberView({
    required this.accountId,
    required this.role,
    required this.status,
    required this.isMe,
    this.name,
  });
  final String accountId;

  /// Their name in the space (ADR-0065), or null when not known here.
  final String? name;
  final SpaceRole role;
  final MemberStatus status;
  final bool isMe;
}
