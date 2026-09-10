# 0020. Retain agents and MCP in the Store product

Status: accepted
Date: 2026-09-09

## Context

The owner inspected the Store demonstration and identified that the missing conversation panel removes a core AppShow feature. The owner explicitly requires a strong effort to retain MCP and connections to both Codex and Claude Code under App Sandbox. ADR 0018's assistant exclusion was a temporary validation boundary, not an approved shipping feature set.

## Decision

Retain the project conversation, streamed agent activity, and typed MCP editing tools as required Store features. Both provider integrations remain in scope. A release without these features requires a new explicit product decision; it is not the default fallback.

Investigate self-contained bundled runtimes with sandbox inheritance and provider-owned authentication. Keep App Sandbox enabled, avoid an unsandboxed escape helper, and do not rely on discovering executables in Homebrew or the user's home directory. Keep provider state and ephemeral workspaces in the container. External project file operations remain in the app's existing permission-aware tool dispatcher.

Local feasibility probes demonstrate both providers starting and connecting to an authenticated MCP fixture inside App Sandbox. These probes do not establish live model turns, editor integration, distribution signing, provider licensing compliance or App Review acceptance. See the [evidence and requirements](../releases/STORE-AGENT-FEASIBILITY.md).

## Consequences

Milestone 21 takes priority over final Store captures. Milestone 20 remains open; final screenshots and preview footage must show the actual retained Store agent experience. The Store compile guards have been replaced with bundled-runtime resolution, container-local state and provider-owned sign-in. Live Codex editing is verified; authenticated Claude, full runtime acceptance and distribution validation remain open.

Provider-specific distribution and authentication conditions must be resolved against the exact package. In particular, Claude Code hosting and SDK integration have different published conditions. An unchanged vendor binary can run inside the tested sandbox, but its original signature passing local verification does not prove App Store distribution eligibility.
