# Feature: bundled agent skills

Status: complete
Milestone: 06

## Contract

1. AppShow ships five canonical skills: `presentation-cut`, `remove-silences`, `spotlight-clicks`, `add-title-cards`, and `music-bed`.
2. Opening a project copies every skill into both provider discovery trees under its sibling `.agent/<project>/` workspace.
3. `AGENTS.md` is the canonical always-on safety guidance; `CLAUDE.md` is a relative compatibility symlink to it.
4. Materialization is idempotent and overwrites AppShow-owned skill copies so app updates take effect. It does not delete unrelated provider skills.
5. Skills reference only tools advertised by the current catalog and state current product limits instead of promising unavailable behavior.

## Safety

- Skills never broaden the tool catalog, filesystem sandbox, confirmation boundary, or Undo model.
- Source recordings and project metadata are never edited directly.
- Visual workflows re-read the timeline after mutation and render representative frames before finishing.
- The music skill does not claim automatic ducking or looping until those primitives exist.
