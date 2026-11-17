// P04b T8 (ADR-0060; p04b-plan.md B1): the spaces of the active profile, as
// the app sees them: its personal workspace and the shared spaces its account
// belongs to. One is shown at a time; every view shows that one.
import 'command.dart' show CommandResult;

enum SpaceRole { owner, editor, viewer }

class SpaceView {
  const SpaceView({
    required this.id,
    required this.shared,
    required this.isShown,
    this.name,
    this.role,
    this.members = 0,
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
}

abstract interface class SpaceService {
  /// The personal workspace first, then the shared spaces by name.
  Future<List<SpaceView>> spaces();

  /// Shows [spaceId]; every view follows (the UI reads them again).
  Future<CommandResult> show(String spaceId);
}
