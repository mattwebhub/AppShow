# ADR 0015: observable permission recovery without gating the editor

Status: accepted, 2026-09-05.

AppShow's permission screen repeated native requests without an explicit Settings link or a way to continue. Main controls were gated on both Screen Recording and Accessibility. A shortcut event tap attempted before Accessibility was granted was never reinstalled.

Toone's local PermissionsService provides the reference pattern: observable shared status, refresh on activation and while permission UI is visible, explicit requests, direct Settings links and a grant callback. AppShow adopts that pattern using a main-actor PermissionStore with injected check/request closures. The app delegate owns it and shares it with the permission screen and menu. The test host uses inert boundaries and tests never access real macOS privacy state.

Capture authorization remains checked at each existing screen-selection/recording boundary. Missing access opens the recovery screen. The editor and toolbar remain accessible, and onboarding offers Continue. Screen Recording is required for capture; Accessibility enables global shortcuts and interactions with external windows. Grant/revocation transitions reinstall or remove the global event tap while keeping local shortcuts.

Recovery actions open the corresponding System Settings pane and reveal the running bundle for replacing stale entries. The app never changes TCC grants or resets other applications' permissions. Local certificate signing continues through the existing ignored Local.xcconfig (ADR 0003); signing does not grant access or prove that a stale system entry is resolved.
