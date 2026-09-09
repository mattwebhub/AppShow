# 0017. Release candidates and update metadata

Status: accepted
Date: 2026-09-09

## Context

The owner authorized implementation of the public-release checklist. The app and feed used the marketing version as the build identifier. Publication tagged before packaging, rewrote the changelog after tagging, pushed unrelated tags, and always required an appcast even though the current updater is inactive.

## Decision

Keep independent public version and numeric build values in `Config.xcconfig`, and validate them against the compiled Release bundle. Derive update delivery from that bundle's Sparkle public key. An absent key means manual downloads; a valid key requires signed update artifacts. The first-release product preference remains pending, so the implementation preserves current manual-download behavior.

Generate feeds with the system Python's XML serializer and atomic writes. Verify the signer's Ed25519 signature with CryptoKit against the actual archive and the app's public key before replacing a feed. Private keys enter the signer through stdin; malformed output and verification failures preserve the previous feed.

Separate preparation, tagging, preview and publication. Preparation starts and ends on the same clean source commit, builds/packages/verifies locally, and writes a receipt binding version/build/update mode, source commit, notes and artifact hashes. Tagging operates only on committed source and never edits the changelog. Publication requires the receipt and matching local tag, validates every artifact, and pushes only that tag. Direct script invocation defaults to a local preview; `make publish` explicitly performs publication after the candidate is reviewed.

## Consequences

The old one-command build/tag/publish behavior is replaced by a reviewable candidate. Python and Swift are already supplied by the required Xcode toolchain; no new package dependency is added. Isolated fixture tests cover failures and remote-write boundaries, while hosted tests inspect compiled identity. Distribution credentials, real signing/notarization, update installation and human acceptance remain release gates, not assumptions made by a successful unit test.
