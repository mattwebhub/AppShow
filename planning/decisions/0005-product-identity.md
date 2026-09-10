# 0005. Product identity of the fork

Status: accepted
Date: 2026-09-03

## Context

The project folder is `appshow`, but the app, bundle id (`eu.jkuri.reframed`), Homebrew cask, `.frm` document type, and Sparkle configuration all say Reframed. Renaming touches Info.plist, the pbxproj product name, the Makefile, the DMG script, and the document UTI declaration. Keeping the name keeps merges trivial but ships under upstream's identity.

## Decision

The product name is **AppShow**. Keep the inherited Reframed name and bundle identifiers during feature development, then perform one mechanical identity migration before the first public release.

The identity migration must cover the app and product names, bundle identifiers, document UTI, application-support paths, release scripts, update feed, package metadata, user-facing copy, and repository documentation. Project-file compatibility must be preserved or migrated explicitly.

The AppShow identifiers are:

- application bundle: `com.mattwebhub.appshow`
- test bundle: `com.mattwebhub.appshow.tests`
- project type: `com.mattwebhub.appshow.project`
- new project extension: `.appshow`

AppShow continues to open legacy `.frm` bundles and registers `eu.jankuri.reframed.project` as an imported legacy type. Renaming a legacy bundle preserves `.frm`; newly created bundles and renamed AppShow bundles use `.appshow`.

The default private data directory moves from `~/.reframed` to `~/.appshow`. On first launch, AppShow moves the legacy directory only when the new directory does not exist. A pre-existing AppShow directory is never overwritten. The old test and agent environment variables remain accepted as compatibility fallbacks for one release while new integrations use the `APPSHOW_` prefix.

## Consequences

- Feature branches used the inherited Reframed symbols and paths until milestone 09, avoiding a rename mixed into behavioral work.
- No externally distributed build may ship under the inherited upstream identity.
- Milestone 09 renames the Xcode project, source roots, products, symbols, paths, release metadata, and repository to AppShow.
- Tests must cover opening projects created before and after the identity migration.
- Existing project metadata stays schema-compatible; changing the filename extension does not rewrite project contents.
