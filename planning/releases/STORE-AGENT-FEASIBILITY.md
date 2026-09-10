# Sandboxed agent feasibility

Checked 2026-09-09 on macOS 26.5.2, Apple Silicon. Product decision: retain project chat, MCP editing tools, Codex and Claude integration in the Store product. Implementation is tracked in [milestone 21](../milestones/21-sandboxed-agents/PLAN.md).

## Result

Both provider binaries started in a native App Sandbox application and connected to a local MCP fixture through AppShow's real `appshow-mcp` executable. The host and an inherited child could write inside the container and were denied an attempted write to an isolated sentinel outside it. This establishes a viable local transport direction. It does not establish authenticated model turns or a shippable Store integration.

The probe is separate from AppShowStore and uses bundle identifier `com.mattwebhub.appshow.sandbox-agent-probe`. Its parent has only `com.apple.security.app-sandbox` and `com.apple.security.network.client`. It does not use test-host read exceptions, broad filesystem grants, an external unsandboxed process, existing provider credentials or a remote model request.

| Check | Observed result |
| --- | --- |
| Parent container write / outside write | Allowed / denied |
| Inherited child container write / outside write | Allowed / denied |
| Codex CLI | Version 0.153.3 starts; stdio app-server initialize succeeds |
| Codex authentication query | Reports no account in fresh container-local CODEX_HOME |
| Claude Code | Version 2.1.263 starts; auth status reports not signed in |
| Real AppShow MCP shim | Authenticated initialize, tools/list and tools/call complete against the fixture |
| Codex MCP discovery | mcpServerStatus/list returns appshow and sandbox_probe |
| Claude MCP health | mcp list reports appshow connected; fixture receives authenticated initialize and tools/list |
| Original Claude executable | Same SHA-256 as the user's installed binary; provider signature preserved; starts and connects inside the parent's sandbox |
| Local signatures | Strict verification passes for the probe and each of five helpers |

Codex and the shim were copied into the probe and signed locally with sandbox/inherit entitlements. Claude was tested both with a local inherited signature and subsequently byte-for-byte unchanged with its vendor signature. The latter avoids assuming that changing its signature satisfies Anthropic's unmodified-binary condition. Neither variant was exported through App Store distribution signing.

The successful MCP tool call uses a diagnostic fixture, not a real editor mutation. Both providers independently discover that fixture through AppShow's shim. Long-running stdio processes are deliberately terminated by the probe after bounded observation; recorded timeout/status 15 for those processes is expected harness shutdown, not evidence of a completed model turn.

Local artifacts are under `dist/sandbox-agent-probe/`: `Probe.swift`, the parent/child entitlements, `results-mcp.jsonl`, `results-pristine-claude.jsonl`, `signature-checks.json`, and the signed probe application. These ignored artifacts include locally installed third-party executables and are not distribution assets.

## Apple requirements

Apple requires Mac App Store apps to be sandboxed and self-contained and limits external installation, downloaded functionality and non-Store updates. The guidelines do not prescribe removal of chat or MCP. Compatibility depends on the actual runtime and data access. [App Review Guidelines 2.4.5 and 2.5.2](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility).

Apple explicitly documents embedding command-line helpers in sandboxed Store apps, with signed code and sandbox inheritance. Its example also explains that Hardened Runtime is recommended but not mandatory for App Store apps. This is the supported starting point for packaging; the final exported executable signatures still need validation. [Embedding a helper tool](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app).

User-selected-file entitlements do not grant permission to execute arbitrary programs outside the bundle/container/app group. A file picker for a Homebrew executable is therefore insufficient. Bookmarks govern file access; they are not a generic execution entitlement. [Sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox).

Personal data transmitted to third-party AI requires disclosure and explicit permission under 5.1.2(i); recording consent does not establish AI-sharing consent. Store screenshots and previews must match the submitted app. [Privacy and metadata guidelines](https://developer.apple.com/app-store/review/guidelines/).

## Provider requirements

OpenAI documents Codex app-server specifically for embedding authentication, conversation history, approvals and streamed events in another product. Its stdio interface supports Codex-managed ChatGPT login and API-key login. The initial proof uses only initialize/account status/MCP discovery; the Store implementation still needs a complete login lifecycle and a live turn. [Codex App Server](https://developers.openai.com/codex/app-server).

Anthropic's current Claude Code hosting guidance permits preinstallation/running in products under its commercial terms and stated conditions: retain the unmodified binary and its authentication methods, and have each end user authenticate and pay under their own agreement. The SDK guidance separately limits offering Claude subscription login in third-party products without approval. AppShow must resolve which integration category and packaging satisfy these conditions; a successful local process launch is not that determination. [Claude Code hosting and authentication](https://code.claude.com/docs/en/legal-and-compliance), [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview).

The support article's June 15 update pauses a proposed change to how Agent SDK usage consumes subscription limits. That billing update alone does not establish distribution or login rights for AppShow. [Claude plan usage update](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan).

## Implementation boundaries discovered

1. `AgentToolchain` currently finds independently installed CLIs through PATH, home-directory locations and a login shell. Store runtime resolution must be explicit and confined to packaged code.
2. Provider state must use container-local CODEX_HOME/CLAUDE_CONFIG_DIR. In the probe, Foundation's home-directory API inside an inherited helper resolved differently from the parent; pass resolved storage paths explicitly.
3. `AgentWorkspace.directory` currently creates a sibling `.agent` directory. A grant to a project bundle does not grant its parent directory. Store ephemeral state belongs in the container, with a short container/temp socket path.
4. The existing app owns selected project-file scopes. Keep actual project reads/writes in its dispatcher and pass previews/structured results to the agent rather than assuming dynamic file grants automatically transfer to children.
5. The actual Store target excludes agent resources and the shim and guards the panel, bridge, runner and readiness probe. Flipping only the UI guard would not restore a functioning assistant.
6. Bundled runtimes, any nested code-mode/runtime helpers, internal auto-updaters, downloads, optional shell dependencies, authentication and shutdown all require exact-candidate tests. The probe exercised no model generation, JIT-heavy agent workload or external third-party MCP server.

The next engineering gate is a signed Store integration with a provider-owned authentication flow and a reversible real edit through each provider. Final screenshots and preview recording follow that gate.
