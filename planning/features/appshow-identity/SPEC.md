# AppShow identity specification

## Outcome

The macOS application, build products, document type, local storage, tooling, release artifacts, and current user-facing material identify the product as AppShow.

## Product identifiers

| Surface | AppShow value | Legacy compatibility |
|---|---|---|
| App name | `AppShow` | none |
| Bundle id | `com.mattwebhub.appshow` | old installation remains a separate bundle |
| Project UTI | `com.mattwebhub.appshow.project` | import `eu.jankuri.reframed.project` |
| Project extension | `.appshow` | open and preserve `.frm` |
| Private home | `~/.appshow` | migrate `~/.reframed` if safe |
| Temporary root | `/tmp/AppShow` | accept old test override variable |
| Environment prefix | `APPSHOW_` | read selected `REFRAMED_` fallbacks |

## Non-goals

- Rewriting version-1 `project.json` data.
- Renaming media files inside a project bundle.
- Rebranding historical architecture notes, upstream-sync records, licence provenance, or recorded third-party fixtures where Reframed is the subject.
- Merging the stacked pull requests.
