# ADR-0089: App-bar titles, one options menu with Search, and one search page
- Status: Accepted (P06b W1 and W2, 2026-11-04; the owner's UI 1 and UI 5)
- Date: 2026-11-04
- Deciders: the owner ([p06b-plan.md](../roadmap/p06b-plan.md) W1, W2); implementation
- Related: [ADR-0073](0073-documents-ui-and-editor-adapter.md) (the Documents screen and its search), [ADR-0077](0077-pdf-text-in-search.md) (PDF pages in the search)
## Context
- The Timeline's month title used a larger text style than the other app-bar titles.
- The only search was a field under the Documents app bar. It took a row of the tree's room and could not be reached from the other screens.
## Decision
1. **Titles.** Every app-bar title uses the theme's app-bar title style; the Timeline month no longer sets a larger one (W1).
2. **One options menu.** Every main screen (Overview, Timeline, Calendar, Documents, Habits, Goals) and the document page end their app bar with one options menu (`OptionsMenu`). **Search is always its first entry**; a screen's own entries follow (the Calendar's zoom and calendars, the document page's history, link, move and trash).
3. **One search page.** Search opens a page above the shell with the field focused. It searches what the Documents field searched (documents with their passage, PDF pages, tasks of the shown space), and it is searched again when the documents change (P05b T6). Back from a hit returns to the results.
4. **The Overview's +** offers Search first, then New list, New event, New task.
5. The search field is removed from the Documents app bar.
## Consequences
- One place to change the search; the Documents tree gets its row back.
- Settings and Profiles have no options menu (nothing there to search from); the Assistant screen (W4) gets one.
- Tests reach the search through the menu (`screen-options` → `options-search` → `search-field`).
