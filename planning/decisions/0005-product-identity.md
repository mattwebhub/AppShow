# 0005. Product identity of the fork

Status: accepted
Date: 2026-09-03

## Context

The project folder is `appshow`, but the app, bundle id (`eu.jkuri.reframed`), Homebrew cask, `.frm` document type, and Sparkle configuration all say Reframed. Renaming touches Info.plist, the pbxproj product name, the Makefile, the DMG script, and the document UTI declaration. Keeping the name keeps merges trivial but ships under upstream's identity.

## Decision

The product name is **AppShow**. Keep the inherited Reframed name and bundle identifiers during feature development, then perform one mechanical identity migration before the first public release.

The identity migration must cover the app and product names, bundle identifiers, document UTI, application-support paths, release scripts, update feed, package metadata, user-facing copy, and repository documentation. Project-file compatibility must be preserved or migrated explicitly.

## Consequences

- Feature branches continue using the current Reframed symbols and paths, avoiding a rename mixed into behavioral work.
- No externally distributed build may ship under the inherited upstream identity.
- A dedicated pre-release milestone will rename the product to AppShow and assign identifiers owned by this project.
- Tests must cover opening projects created before and after the identity migration.
