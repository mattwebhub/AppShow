# AppShow identity test plan

## Unit and integration tests

1. Identity constants expose the accepted app, bundle, UTI, and extension values.
2. AppShow path overrides take precedence over legacy overrides.
3. Legacy overrides still resolve during the compatibility window.
4. A legacy home directory moves when the AppShow destination is absent.
5. A populated AppShow home is never replaced by a legacy home.
6. Newly created projects use `.appshow`.
7. Existing `.frm` projects still open.
8. Rename keeps a legacy `.frm` extension and an AppShow `.appshow` extension.
9. Hosted bundle metadata contains the AppShow app and document identifiers.
10. Full tests continue decoding version-1 project metadata and persisted conversations.

## Release checks

- The built product is `AppShow.app` and contains `appshow-mcp`.
- The DMG and appcast scripts agree on `AppShow-<version>.dmg`.
- Active current-product copy contains no unintended Reframed branding.
