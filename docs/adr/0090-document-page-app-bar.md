# ADR-0090: The document page's app bar
- Status: Accepted (P06b W3, 2026-11-04; the owner's UI 2)
- Date: 2026-11-04
- Deciders: the owner ([p06b-plan.md](../roadmap/p06b-plan.md) W3); implementation
- Related: [ADR-0073](0073-documents-ui-and-editor-adapter.md) (the document page), [ADR-0089](0089-app-bar-options-and-one-search.md) (the options menu)
## Context
The document page showed the title twice (in the app bar and as a large field above the text), a status line under it, a read-aloud button on the bar, and a backlinks panel under the text. On a phone this left little room for the text.
## Decision
1. **The title fills the app bar.** A title too long for it slides once inside its own box and then rests cut (the Timeline's `MarqueeText`). The bar follows what is typed.
2. **Editing the title.** A button beside it (expand/collapse) opens the title as a field under the bar, focused with the cursor at its end. The button again, or Enter, closes it and saves soon. The button is not there when the page is read only (a viewer, the trash, unreadable, reading aloud).
3. **The save state is an icon** on the bar: saved, saving, not saved yet, or view only, each with its own icon. Its tooltip has the words (in a shared space also who changed it last), and a tap says them, for touch screens. The status line is gone. In the trash there is no icon; the banner says why nothing is saved.
4. **The options menu** (Search first, ADR-0089) has **Read aloud** (then "Stop reading aloud" while the reader is open), **Backlinks and linked items**, then History, Link, Move, Space and Trash as before.
5. **Backlinks and linked items open in a sheet** from the menu. Unlinking in the sheet updates it at once. The panel under the text is gone.
6. The ✨ Ask button stays on the bar: it is the way in from a document.
## Consequences
- The text gets the rows of the title field, the status line and the panel.
- Tests open the title with `doc-title-edit`, read the state from `doc-status`'s tooltip, and reach read aloud and the links through `doc-page-menu`.
- The P05a/P05b device checks that name the old controls are history; the P06 device check is updated for the new ones after W6.
