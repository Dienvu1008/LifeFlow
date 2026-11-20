# P05a T10: documents on the owner's devices

The owner's check of P05a on real devices:
- alone on Windows and on Android, with the same account A;
- with a second account B in a shared space, A on Windows and B on Android, as in [p04b-two-person-run.md](p04b-two-person-run.md).

The build is the branch `p05a/t10-devices`, with `main` at `c433c86` (T1–T9 merged). Plan row: [p05-plan.md](../roadmap/p05-plan.md) T10. Status: **waiting for the owner's run**.

The server needs nothing new for P05a. Documents, revisions and document links are sealed records like every other (ADR-0069, ADR-0070), so there is no migration to push.

## Setup

- Build with the hosted project, as in the app README:
  - Windows: `flutter build windows --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
  - Android: `flutter build apk --release` with the same two defines.
- Windows: account A, signed in, sync on, "When to sync" Automatic.
- Android: A first (steps 1–20), then B as in P04b T14: sign out A, sign in B, sync on (steps 21–30).
- Keyboards for Vietnamese:
  - Android: Gboard with Vietnamese, Telex and VNI if possible, and Laban Key if installed.
  - Windows: the built-in Vietnamese keyboard, and Unikey or EVKey (Unicode).
- A long text for step 9: about 50 pages, for example a chapter of a book or several of LifeFlow's docs pasted together.

Known limits (ADR-0073):
- A web link is copied when tapped, not opened.
- Events cannot be linked from a document.
- The UI is in English.
- Titles are not in Vietnamese dictionary order.

## Steps and results

| # | Where | Step | Expected | Result |
|---|---|---|---|---|
| 1 | Windows | Drawer: Documents is right after Calendar; "+" → "Ghi chú họp" → Add | The page opens; the line under the title says "Saved" | |
| 2 | Windows | Type a few lines in Vietnamese with headings, a bulleted list, a to-do (tick it), bold and italic | Typing is smooth; marks are placed right; "Not saved yet", then "Saved" about 10 s after you stop | |
| 3 | Windows | Leave the page and open it again | Everything is there as typed | |
| 4 | Windows | Type `[[`, pick another document (make one first if needed); then `[[` again, type a new title → "Create …" | A link with the document's title; the new document exists in the tree | |
| 5 | Windows | Rename the linked document; open the first one again | The link shows the new title | |
| 6 | Windows | Open the linked document → "Backlinks · Linked" at the bottom | The first document is a backlink, with its sentence | |
| 7 | Windows | Menu → "Link to a task or goal…" → find a task → pick it; open that task | The document shows under Linked, and the task's page lists the document | |
| 8 | Windows | "Attach a file": a picture, then a PDF | The picture shows; the PDF shows with "Save a copy", which saves the same file | |
| 9 | Windows | New document; paste the long text (about 50 pages) | Pasting, scrolling and typing at the end are smooth (time how long the paste takes); saved | |
| 10 | Windows | Menu → History | One version per save, newest first; open an older one → "Restore this version" brings it back as a new version | |
| 11 | Windows | Search at the top of Documents: "ghi chú", "Ghi Chú", "ghi chu", "ghi ch" | The first two and the last find "Ghi chú họp" with the words in bold; "ghi chu" finds nothing (C4); tasks with those words show under Tasks | |
| 12 | Windows | A subdocument: document menu → "New subdocument"; then "Move under…" another; fold the parent | Indented under its parent; folding hides it | |
| 13 | Windows | Move a document with subdocuments to the trash; trash (top right) → Restore | Gone with its subdocuments; back with them | |
| 14 | Android | Sync; Documents | The documents of steps 1–13 are there, with their links and history; the picture and the PDF show "On another device · name · size" | |
| 15 | Android | Steps 2, 4 and 11 with Gboard (Telex and VNI), and with Laban Key if installed | Marks are typed right, nothing is doubled or lost; `[[` opens the list; search finds "ghi chú" typed either way | |
| 16 | Android | Step 9 (the long text) | Smooth enough to use (the S-07 check, now in the app) | |
| 17 | Android | Put the app in the background right after typing; reopen it | The text is saved (C7) | |
| 18 | Both | Both offline; change the same paragraph differently on each; Windows online → Sync; then Android online → Sync | One device has "Changes to review" (Settings → Sync); History shows both versions; "Take the other" works; both devices end the same (GS-08) | |
| 19 | Windows | Profiles → "Export this profile" → Export | The file is a `.zip`; Windows opens it: `lifeflow-export.json` and `attachments/…` | |
| 20 | Windows | Profiles → "Restore from a file" → the `.zip` of step 19 | "Nothing to restore" (the file and the profile are the same); nothing changes | |
| 21 | A Windows, B Android | Space "Family" (or the one from P04b); A: document menu → "Move to a space…" | The dialog says what moves, with "… and N earlier versions" (C8) | |
| 22 | B | Documents in the space | The document, its subdocuments and its history, with A as the author; a file shows "On another device" | |
| 23 | B | Edit the document | A sees the change within a minute; the line under the title says "Changed by B"; History shows B's version by B's name | |
| 24 | A | Members → B → "Make Viewer" | B: no "+", no toolbar, "View only"; nothing can be changed | |
| 25 | A | "Make Editor" again; B types `[[` | B is offered only documents of the space, never A's personal ones | |
| 26 | A | Move the document back out ("Move to Personal…") | B no longer sees it; A keeps it, with B's versions in its history | |
| 27 | B | Search in the space | Only the space's documents and tasks | |
| 28 | A | Profiles → Export | The export holds A's personal documents only, not the space's | |
| 29 | Android | Sign out B; sign in A again | A's personal documents are back on Android | |
| 30 | Both | Anything that felt wrong or slow | Noted under Findings | |

## Findings

(none yet)
