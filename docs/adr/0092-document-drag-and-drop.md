# ADR-0092: Dragging documents in the tree
- Status: Accepted (P06b W5, 2026-11-04; the owner's UI 3)
- Date: 2026-11-04
- Deciders: the owner ([p06b-plan.md](../roadmap/p06b-plan.md) W5); implementation
- Related: [ADR-0051](0051-dogfooding-pass-1.md) (the Overview's drag: handles, long press, the dragged copy), [ADR-0073](0073-documents-ui-and-editor-adapter.md) (the documents tree)
## Context
Documents could only be moved with "Move under…", which puts a document first under its new parent. The owner asked to drag them to their place as items are dragged in the Overview.
## Decision
1. **Shared drag pieces.** The Overview's handle setting, drag scope, handle, long-press drag and dragged copy move to `widgets/row_drag.dart`, unchanged in behaviour. Each list keeps its own drop targets, because where a drop lands depends on its rows.
2. **Starting a drag in the tree** works as in the Overview: by the handle where handles are shown (the setting; on a desktop by default), or by a long press on the row (on touch, and where handles are hidden). A viewer of a shared space drags nothing.
3. **Where it lands** (`resolveDocumentDrop`), by the part of the row under the pointer:
   - **top quarter: before** the row, under the row's parent;
   - **middle: into** the row, as its last subdocument;
   - **bottom quarter: after** the row. When the row is open and has subdocuments (they show right below it), it becomes the row's first subdocument.
4. **What cannot happen:** a document cannot be dropped on itself or under itself (DOC-001; the service refuses it too). A drop where it already is sends nothing. Where it cannot land, no line or highlight shows.
5. **What the person sees:** a line at the depth it will take (before or after), or the row highlighted (into). The dragged document and its subdocuments fade while dragged. A folded document that receives one opens, so the moved document is seen there.
6. The move is one `DocumentService.move(id, parentId, afterId)` command, as "Move under…" sends.
## Consequences
- The Overview and the tree share one look and one handle setting.
- Moving by keyboard stays with "Move under…" in the row's menu.
