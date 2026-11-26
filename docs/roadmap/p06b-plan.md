# P06b plan: the assistant in the navigation, free chat, and five UI changes
- Status: **Agreed by the owner 2026-11-04** (answers in §4). W1 and W2 built ([ADR-0089](../adr/0089-app-bar-options-and-one-search.md)), W3 built ([ADR-0090](../adr/0090-document-page-app-bar.md)); W1–W3 merged. W4 merged ([ADR-0091](../adr/0091-free-chat.md)). W5 merged ([ADR-0092](../adr/0092-document-drag-and-drop.md)). W4b merged ([ADR-0093](../adr/0093-chat-events.md)). W6 merged ([ADR-0094](../adr/0094-archive-and-trash.md)). All of W1–W6 are on `main`. The device check list (89 steps, [p06-device-check.md](../testing/p06-device-check.md)) is written on `p06b/device-check`; next: the owner's check, then the exit gate (P06 T9).
- Date: 2026-11-04
- Why: using the app, the owner could not find the assistant. The only ways in were the ✨ buttons on the Calendar, a document and a PDF, plus Settings → Assistant. He reversed P06 D1 ("no free chat") and asked for five UI changes.
- Inputs:
  - [p06-plan.md](p06-plan.md) D1–D10;
  - [ADR-0087](../adr/0087-assistant-ui.md) (no free chat; this plan supersedes that part);
  - [ADR-0016](../adr/0016-data-classification-and-egress-policy.md) (the egress matrix);
  - [p06-device-check.md](../testing/p06-device-check.md) (on the T8 branch, not merged yet; some steps change with this work).
- Relation to P06: P06 T8 (device check) and T9 (exit gate) stay. The exit gate is checked after this work, so the device check covers the new screens.

## 1. Decision change
- **D1 (new, owner 2026-11-04):** the assistant keeps the day plan, conflict fixing and "ask about a document", and gets
  - an **Assistant** destination in the main navigation;
  - a **free chat** with several turns.
- Every other P06 decision holds. In particular:
  - the assistant never changes anything by itself (LF-INV-AI-001);
  - Restricted data never goes to a cloud model; Confidential data goes only with the cloud option on and a consent sheet (D6);
  - the chat history syncs, end-to-end encrypted (D7).
- A new ADR records the change and marks the "no free chat" part of ADR-0087 as superseded.

## 2. The work

### W1. Timeline title size (UI 5)
- `TimelineTitle` (timeline_view.dart) uses `titleLarge`. It will use the app-bar title style, as the Overview and Documents titles do.
- Small. Tests: the title's text style equals the app bar's.

### W2. Search everywhere (UI 1)
- A shared **search screen** (or full-screen search sheet) over `SearchQueries.search`: documents, tasks by title, PDF pages. Results open the item.
- A shared **options menu** helper for app bars. Every main screen (Overview, Timeline, Calendar, Documents, Habits, Goals, and the document page) shows Search as its first entry. Screens that already have menu items (Calendar, document page) keep them below Search.
- The Overview **+** button (speed dial) gets a fourth entry, **Search**, next to New list, New event, New task.
- The search field is removed from the Documents app bar; its results list moves to the shared search screen.

### W3. Document page app bar (UI 2)
- The **title moves into the app bar** and fills it. A long title scrolls inside its own box (marquee or horizontal scroll; to be tried on the device).
- An **expand/collapse** button next to the title. Expanded: the title shows below the app bar as an editable field with the cursor in it. Collapsed: back to the app-bar title.
- **Save state as an icon** in the app bar (for example a cloud or check icon for saved, a dot or spinner for not yet saved), with a tooltip that says the state in words. The status line below the title goes away.
- **Read aloud, backlinks and links** move into the options menu. Backlinks and links open in a sheet instead of the panel at the bottom of the page.
- The ✨ Ask button stays in the app bar (it is the main way in from a document). If the bar is too crowded on a phone, it moves into the menu too.

### W4. Assistant destination and free chat (directions 1 and 2)
- **Navigation:** a new **Assistant** destination in the drawer and the rail (proposed place: after Calendar). Router, branches and the known roots are updated; Profiles moves to the next index.
- **The Assistant screen** shows:
  - a chat input at the bottom;
  - shortcuts: "Plan my day", "Fix conflicts";
  - the history of earlier chats and proposals (today's `AiHistoryList`).
- **Free chat:**
  - a new purpose `AiPurpose.chat`, with its own egress row;
  - several turns: earlier messages of the session go with each new question (bounded by a token budget; the oldest turns drop first);
  - context: search hits for the question (documents, tasks, PDF pages) across **all spaces of the profile** (Q2), at most 8 per kind; each hit keeps its own classification, so the egress rules still decide per item what may go to a cloud model;
  - routing through `chooseAiRoute` (local first; cloud only if enabled; decline rather than lower privacy);
  - the consent sheet before anything Confidential goes to a cloud model;
  - answers stream in when the engine supports it;
  - the sessions are saved in the history and sync (D7).
- **The chat may propose changes** (Q1): create, rename or schedule tasks of the personal space (ADR-0091; events and shared spaces' tasks are read, not changed, in W4). Each change shows as a proposal card in the chat and runs only after the person approves it (D8, LF-INV-AI-001); a stale proposal is refused (LF-INV-AI-002).

### W4b. The chat creates and moves events (the owner, 2026-11-04)
- After W4 the owner asked for events too: the chat may propose a new event (title, day, start and end) and moving an event of the personal space to another time, approved as every change.
- Needs event tools in the proposal catalog (create, a new time), checked as the task slot is, and the events of the coming days marked "changeable" in the chat's data.
- A repeating event is not moved as a whole: only one of its days (as the Calendar's "this event only").

### W5. Drag and drop for documents (UI 3)
- The Overview's drag code (drop slots, handles, long-press drag, `resolveDrop`) is private to overview_tree.dart and tied to Overview rows. It is extracted into a shared, row-agnostic widget; the Overview keeps working the same (its tests must stay green).
- The documents tree uses it. A drop maps to `DocumentService.move(id, parentId, afterId)`: before or after a sibling, or into a document as its child.
- A document cannot be dropped into itself or into its own children (the service already refuses it; the UI does not offer the slot).

### W6. Trash and Archive screens (UI 4)
- Today:
  - only documents and goals have a trash screen;
  - tasks, lists and events can be trashed and restored by command, but there is no query for the trashed ones and no screen;
  - nothing can be deleted for good;
  - only goals can be archived.
- Agreed (Q3–Q5):
  - one **Trash** screen with filters (tasks, lists, events, documents). Each item has **Restore** and **Delete forever**; the screen has **Empty trash**. Delete forever asks for confirmation.
  - trashed items are **deleted for good after 30 days** by default. The number of days is a setting (Settings), applied when the app opens and once a day while it runs. The purge also removes the item's dependants (a list's tasks and events, a document's children) and syncs as a delete.
  - an **archive** action on **tasks, lists, events and documents**, and one **Archive** screen with **Unarchive**. Archived items leave the Overview, the documents tree and search, but are not deleted.
  - **archiving a list archives all its tasks and events**; unarchiving the list brings them back (items archived on their own before stay archived).
  - a setting for archived items that were scheduled: **show them on the Calendar and Timeline, or hide them** (default: hide).
  - Trash and Archive are entries in the **navigation drawer** (and the rail), below the main destinations.
- This is the largest item. It needs a schema change (a new column or status), new queries, sync of the new field, and the agenda filter to respect it.
- A bug found while reading the agenda code: a cancelled one-off task in the past can be shown as overdue. It is fixed in this item, with a test.

## 3. Order and size
| # | Item | Size | Notes |
|---|---|---|---|
| W1 | Timeline title size | small | first, warms up the branch flow |
| W2 | Search everywhere | medium | the shared options menu is reused by W3 |
| W3 | Document app bar | medium | depends on W2's menu |
| W4 | Assistant destination and free chat | large | the core of the request |
| W5 | Document drag and drop | medium | refactor of the Overview drag code |
| W4b | The chat creates and moves events | medium | added by the owner after W4 |
| W6 | Trash and Archive | large | schema change (archive field, purge) |

- Every item: its own branch, headless tests, mutation checks, docs, CI green, a Vietnamese handoff, merge after the owner approves.
- After W6: update p06-device-check.md for the new screens, then the owner's device check (P06 T8) and the exit gate (T9).

## 4. The owner's answers (2026-11-04)
- **Q1.** The chat may propose changes (always as proposals the person approves).
- **Q2.** The chat reads all spaces of the profile.
- **Q3.** The Trash has Delete forever; items are deleted automatically after 30 days, and the number of days is a setting.
- **Q4.** Archive applies to lists, tasks, events and documents. Archiving a list archives its tasks and events.
- **Q5.** Trash and Archive are reached from the navigation drawer.
- **Q6.** The order in §3 stands.
