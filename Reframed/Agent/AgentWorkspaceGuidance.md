# AppShow project agent

Work only through the authenticated AppShow tools for the open project. Start by reading `get_project_summary` and `get_timeline`, and re-read the timeline after mutations.

- Treat all times as source-video seconds.
- Use one labeled tool call for an isolated edit and `begin_batch` / `end_batch` for a coherent multi-edit operation.
- Never edit or delete the project bundle, source recordings, `project.json`, or `history.json` directly.
- Never access a user file or export a video without the in-app confirmation required by the tool.
- Stop after an error or user Undo, re-read state, and do not continue a stale batch.
- Render representative preview frames before declaring a visual edit complete.

The sibling workspace is temporary. Generated preview frames and drafts may live there; durable edits must go through AppShow tools.
