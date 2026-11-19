# ADR-0073: The Documents destination, the editor behind an adapter, saving by itself

- Status: Accepted (P05a task T8, 2026-11-04); the owner checks it on his devices in T10
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) (the owner's C5, C7, C10, §4) and S-07 (flutter_quill 11.6.0, [spike-results.md](../spikes/spike-results.md))
- Related: [ADR-0020](0020-editor-decision-or-spike.md), [ADR-0066](0066-document-record-model.md), [ADR-0068](0068-document-commands.md), [ADR-0070](0070-documents-in-shared-spaces.md), [ADR-0071](0071-document-links-and-search.md), [ADR-0072](0072-encrypted-attachments.md)

## Context
T1–T7 gave documents a format, a store, commands, sync, spaces, links, search and files, all below the ports. The owner chose flutter_quill in S-07. Its format (a Delta) must not become LifeFlow's stored format (ADR-0020, ADR-0066).

## Decision
1. **The destination** (C10). "Documents" sits right after Calendar: Overview, Timeline, Calendar, Documents, Habits, Goals, Settings (`/documents`; Profiles is branch 7). It shows:
   - the tree of the shown space, indented, with folding;
   - one search at the top over documents and tasks (`SearchQueries`, ADR-0071), with the matched words in bold;
   - "New document" and the trash.

   A document's menu has "New subdocument", "Move under…" (never under itself or its subdocuments), "Move to a space…" (P04b's confirmation, with the revision count of ADR-0070) and "Move to trash".
2. **The editor sits behind an adapter** (`ui/src/documents/quill_adapter.dart`), the only code that knows Quill.
   - **Lines.** One Quill line is one block, and its attributes give the block type: headings 1–3, bulleted, numbered, to-do with its tick, quote, code, and the indent of lists and to-dos (0–5).
   - **Inline.** Bold, italic, underline, strike and code. A `[[…]]` link is a Quill link to `lifeflow-doc:<id>`; a web link keeps its http, https or mailto address.
   - **Files.** An attachment is a block embed of its own type (`lifeflow-file`) that carries the reference.
   - **Dropped.** Anything else pasted in is dropped rather than stored half-read: colours, sizes, alignment, other link schemes, pictures pasted from elsewhere (use "Attach a file").
   - **Text beside a file.** When Quill puts a file and text on one line, the adapter keeps the text as a block of its own. An integration test found that the first version lost that text. The page also puts a new file on a line of its own.
   - **Block ids** are kept by line position since the load (ADR-0066 §5).
3. **Saving by itself** (C7) on the document's page, with no Save button. It saves:
   - 10 s after the last change (`documentIdleSave`);
   - when the page is left, whether by "back" or because the page is taken down (a profile switch);
   - before another document opens from a link;
   - when the app goes to the background (inactive, hidden, paused).

   Only one save runs at a time. If nothing changed, nothing is written: the comparison is with what the editor was given, so opening and leaving writes no revision. Each save is a revision (C5). The line under the title says Saved, Saving… or Not saved yet. In a space it also shows who changed the document last.
4. **A change from another device while writing.** The page's save still goes through, and both versions are in the history (DOC-002, ADR-0069). A message says so and offers "Open again". Silently dropping either text would break DOC-005.
5. **Links on the page** (§4):
   - Typing `[[`, or the link button, opens the picker: documents by title (ADR-0071), never the document itself, and "Create '…'" where the person may write.
   - A link shows its target's current title from the moment the page opens.
   - Tapping a link opens the target after saving this document. A broken link explains why: in the trash, or not here.
   - Tapping a web link copies its address, because the UI package has no URL launcher.
   - Under the text, a panel shows the backlinks with their sentences, and the linked tasks, events and goals with their state. Each can be opened (events not yet) and unlinked.
   - "Link to a task or goal…" in the menu finds tasks by title and lists the goals. Events cannot be linked from here yet, because there is no event search.
   - A task's page and a goal's page list their documents.
6. **The history** (C5, C9) lists versions newest first, each with its reason (saved, kept from a change on two devices, restored), time, author ("you" or the member's name) and device. A version opens read-only and "Restore this version" makes it a new version (ADR-0068).
7. **Files** (ADR-0072). "Attach a file" uses the new `FileGateway.pickFile` with a 25 MB limit checked before reading. A file then shows as one of:
   - a picture inline;
   - a file with "Save a copy" (`FileGateway.saveBytes`);
   - "On another device · name · size";
   - "Cannot be read".

   The app sweeps unnamed files when a profile opens, without waiting for it.
8. **Never edited over.** A viewer, a document in the trash (shown with Restore) and a body this app cannot read (shown with its history) are read-only. They have no toolbar and are never saved. No document can be added where the space is only viewed (B4).
9. **Licenses.** flutter_quill 11.6.0 brings 26 more packages, all MIT, BSD-3-Clause or Apache-2.0. They are listed with exact versions in `license_inventory.txt` (FF-ARCH-07) and in VS-47. The editor's own strings come from `FlutterQuillLocalizations`. All new UI text is in the ARB file (FF-ARCH-10). The document kinds have names in "Changes to review".

## Consequences
- Replacing flutter_quill means rewriting the adapter, the toolbar and the embed builder. The stored documents, their revisions and their sync do not change.
- An inline image pasted from another app is not kept. "Attach a file" is the way.
- Not in T8, left for later:
  - opening web links;
  - linking events from a document;
  - showing in Settings how much space documents use (C9);
  - Vietnamese UI strings (U-D11: English only for now);
  - sorting titles in Vietnamese order (ADR-0071).
- T10 checks speed and typing on the owner's Windows and Android, including Vietnamese input, the 50-page case of S-07, and the `[[` trigger with real keyboards.

## Verification
- `ui/test/quill_adapter_test.dart` (new, 5 tests): every block type, mark and link through Quill and back, with ids; ids by line; an empty editor; text and a file on one line; what is dropped.
- `ui/test/documents_flow_test.dart` (new, 13 tests):
  - the destination's place; New document;
  - saving at 10 s idle (and not before), on back, when the page is taken down, in the background, before following a link;
  - the tree (indent, fold, new subdocument, move under, trash with subdocuments, restore);
  - search with tasks;
  - `[[` with current titles, "Create …" and backlinks;
  - linking and unlinking a task;
  - history and restore;
  - files here and elsewhere, "Save a copy";
  - a viewer; a document in the trash; an unreadable body;
  - a task's documents.
- `ui/test/shell_test.dart`, `schedule_flow_test.dart`: seven destinations in order.
- `apps/lifeflow_app/test/app_integration_test.dart`: a document made in the real app is stored with its revisions and audit rows, found by search, and its file is kept encrypted.
- Mutations: 19 run one at a time; 18 killed in the end.
  - The save when a page is taken down survived the first run. A new test then found a real bug: the service was read lazily in `dispose`, when Riverpod's ref is gone. The bug is fixed and the mutation is killed.
  - One survivor is equivalent: putting a new file on a line of its own. The adapter already splits such a line, so the stored result is the same.
