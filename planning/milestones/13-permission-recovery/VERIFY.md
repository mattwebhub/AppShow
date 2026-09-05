# Permission recovery verification

- Initial red tests establish the missing shared permission store.
- Four isolated permission tests pass: no startup request, grant/revocation callbacks once per transition, explicit request/refresh and ignored requests remaining denied.
- 737 tests in 84 suites pass; format, strict lint, warning-free Debug build, project validation and signature verification pass.
- Reopened the signed Debug bundle. Its runtime log reported `screenRecording=false, accessibility=false`, confirming that the running process was denied both capabilities.
- Reset only `ScreenCapture` and `Accessibility` for `com.mattwebhub.appshow` using macOS tccutil and reopened the app for fresh user grants. Other applications and permission services were not reset.
- Build/test logs: `/tmp/appshow-permissions-tests.log`, `/tmp/appshow-permissions-build.log`, `/tmp/appshow-permissions-lint.log`. Runtime status: `/tmp/appshow-permission-session.log`.
- Actual user grants, recording and gesture checks remain pending.

Manual checks:

- Relaunch the signed Debug app and inspect its reported Screen Recording and Accessibility states.
- Open each Settings pane, change access and return; check status refreshes and global shortcuts become available after Accessibility is granted.
- Use Continue without grants and open/edit a project. Attempting screen capture must return to recovery while denied.
- If Settings has a stale entry, reveal the exact bundle and re-add it through macOS, then quit/reopen.
- Check that the Continue button remains visible when recovery text needs scrolling.

The real macOS grant remains a user action; automated tests do not establish that capture is authorized on this machine.
