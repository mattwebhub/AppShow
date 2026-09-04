# 0005. Product identity of the fork

Status: proposed
Date: 2026-09-03

## Context

The project folder is `appshow`, but the app, bundle id (`eu.jkuri.reframed`), Homebrew cask, `.frm` document type, and Sparkle configuration all say Reframed. Renaming touches Info.plist, the pbxproj product name, the Makefile, the DMG script, and the document UTI declaration. Keeping the name keeps merges trivial but ships under upstream's identity.

## Decision

Pending owner input. Options:

1. Keep the name and bundle id for now, rename right before first external distribution.
2. Rename now to the product name with our own reverse-DNS bundle id.

Recommendation: option 1 until a product name is settled, because a rename is a mechanical one-day task and doing it twice costs more than doing it late.

## Consequences

To be filled when accepted.
