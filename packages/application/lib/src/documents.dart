// P05a T3 (ADR-0068; p05-plan.md): documents as the UI and the app see them.
// The body's value types are the domain's (ADR-0066): they are the published
// language of this port, re-exported here so the UI never imports `domain`
// (FF-ARCH-04) and never sees the editor library's format.
import 'package:domain/domain.dart' show DocumentBody, RevisionReason;
import 'package:foundation/foundation.dart';

import 'command.dart';

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
        maxDocumentTitleLength;

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

class DocumentItemLinkView {
  const DocumentItemLinkView({required this.itemType, required this.itemId});
  final DocumentItemType itemType;
  final String itemId;
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
}
