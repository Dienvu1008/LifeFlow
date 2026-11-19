// P05a T3 (ADR-0068; p05-plan.md): documents as the UI and the app see them.
// The body's value types are the domain's (ADR-0066): they are the published
// language of this port, re-exported here so the UI never imports `domain`
// (FF-ARCH-04) and never sees the editor library's format.
import 'package:domain/domain.dart' show DocumentBody, LinkState, RevisionReason;
import 'package:foundation/foundation.dart';

import 'command.dart';
import 'goals.dart' show LinkedItemState;

export 'package:domain/domain.dart'
    show
        AttachmentRef,
        BlockType,
        DocBlock,
        DocumentBody,
        LinkState,
        RevisionReason,
        TextMark,
        TextRun,
        backlinkSnippets,
        documentIdleSave,
        documentTitleError,
        maxAttachmentNameLength,
        maxBlockIndent,
        maxDocumentBlocks,
        maxDocumentTextLength,
        maxDocumentTitleLength,
        withLinkTitles;

enum DocumentItemType { task, event, goal }

/// A document in the tree (no body).
class DocumentNodeView {
  const DocumentNodeView({required this.id, required this.title, this.parentId, required this.orderKey});
  final String id;
  final String title;
  final String? parentId;
  final String orderKey;
}

class DocumentView {
  const DocumentView({
    required this.id,
    required this.title,
    required this.body,
    required this.version,
    required this.updatedAt,
    this.parentId,
    this.isTrashed = false,
    this.changedBy,
    this.isUnreadable = false,
  });
  final String id;
  final String title;

  /// Empty when [isUnreadable].
  final DocumentBody body;
  final int version;
  final Instant updatedAt;
  final String? parentId;
  final bool isTrashed;

  /// In a shared space: who changed it last (an account id).
  final String? changedBy;

  /// P05a T4: a body this app cannot read (written by a newer app, or
  /// damaged): shown as such, never edited over.
  final bool isUnreadable;
}

/// One entry of a document's history, newest first (C5, C9).
class DocumentRevisionView {
  const DocumentRevisionView({
    required this.id,
    required this.documentVersion,
    required this.title,
    required this.reason,
    required this.savedAt,
    this.author,
    this.deviceId,
  });
  final String id;
  final int documentVersion;
  final String title;
  final RevisionReason reason;
  final Instant savedAt;

  /// Who saved it: an account id in a shared space, else null (oneself).
  final String? author;
  final String? deviceId;
}

/// A task, an event or a goal a document is linked to, read from its own
/// context (P05a T6): its title, or missing when it is gone.
class DocumentItemLinkView {
  const DocumentItemLinkView({required this.itemType, required this.itemId, this.title, this.state = LinkedItemState.open});
  final DocumentItemType itemType;
  final String itemId;

  /// Null when [state] is missing.
  final String? title;
  final LinkedItemState state;
}

/// P05a T6: what a `[[…]]` link shows (DOC-003): its target's current
/// title, or a broken link (in the trash, or not in this workspace).
class DocumentLinkTarget {
  const DocumentLinkTarget({required this.id, required this.state, this.title});
  final String id;
  final LinkState state;

  /// The current title; null when [state] is missing.
  final String? title;
}

/// P05a T6 (C6): a document whose text links to the one shown, with the
/// sentence around each link.
class BacklinkView {
  const BacklinkView({required this.id, required this.title, required this.snippets});
  final String id;
  final String title;
  final List<String> snippets;
}

/// Document commands; failures are returned, never thrown.
abstract interface class DocumentService {
  /// A new document, empty, at the end of [parentId]'s subdocuments (or
  /// after [afterId]). Its first revision is written with it.
  Future<CommandResult> create(String title, {String? parentId, String? afterId});

  /// Stores the title and the body as one revision (C5, C7). When nothing
  /// changed since the stored version, nothing is written and the result is
  /// a success with the current version.
  Future<CommandResult> save(String id, {required String title, required DocumentBody body});

  /// A new title is a save too (a revision with the current body).
  Future<CommandResult> rename(String id, String title);

  /// Under [parentId] (null: the top), after [afterId] (null: first);
  /// never under itself or its subdocuments (DOC-001).
  Future<CommandResult> move(String id, {String? parentId, String? afterId});

  /// To the trash with its subdocuments; restore brings back the same ones.
  Future<CommandResult> trash(String id);
  Future<CommandResult> restore(String id);

  /// An earlier revision becomes the document again, as a new revision.
  Future<CommandResult> restoreRevision(String id, String revisionId);

  /// The item must be live and in the document's workspace (DOC-004).
  Future<CommandResult> link(String id, DocumentItemType type, String itemId);
  Future<CommandResult> unlink(String id, DocumentItemType type, String itemId);
}

abstract interface class DocumentQueries {
  /// The live documents of the shown workspace, in tree order.
  Stream<List<DocumentNodeView>> watchTree();

  /// A document of the shown workspace (in the trash too), or null.
  Future<DocumentView?> document(String id);

  /// Its history, newest first.
  Future<List<DocumentRevisionView>> revisions(String id);

  /// One revision's title and body; null when there is none, or its body
  /// cannot be read.
  Future<(String, DocumentBody)?> revisionContent(String revisionId);

  /// The tasks, events and goals it is linked to (live links).
  Future<List<DocumentItemLinkView>> linksOf(String id);

  Future<List<DocumentNodeView>> trashed();

  /// P05a T6: the live documents of the shown workspace linked to a task,
  /// an event or a goal (shown on the item's page), by title.
  Future<List<DocumentNodeView>> documentsOf(DocumentItemType type, String itemId);

  /// P05a T6 (DOC-003): what each `[[…]]` link to [ids] shows. A link
  /// resolves only inside the shown workspace: a document elsewhere is
  /// missing, its title never shown.
  Future<Map<String, DocumentLinkTarget>> linkTargets(Iterable<String> ids);

  /// P05a T6 (C6): the live documents of the shown workspace whose text links
  /// to [id], by title, each with its sentences.
  Future<List<BacklinkView>> backlinks(String id);

  /// P05a T6 (§4): what typing `[[` offers: the live documents of the shown
  /// workspace whose title matches [typed] (as search does, C4), best
  /// first; with nothing typed, the latest changed. Never [excludeId].
  Future<List<DocumentNodeView>> linkCandidates(String typed, {String? excludeId});
}
