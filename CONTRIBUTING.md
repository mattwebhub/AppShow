# Contributing to AppShow

AppShow is a native Mac app for making screen recordings feel considered. Contributions should make recording, editing, and sharing clearer, more reliable, or more expressive.

## Start here

Read [AGENTS.md](AGENTS.md) for the build, architecture, and code conventions, then check [the current plan](planning/STATE.md). For a substantial feature or design change, open an issue describing the user need and the proposed interaction before starting implementation.

Small bug fixes, documentation corrections, and focused improvements can go straight to a pull request.

## Run locally

Use macOS 15 or later and Xcode with Swift 6. Clone the repository and run:

```sh
make dev
```

The default signing configuration works ad-hoc. Personal signing belongs in the ignored `Local.xcconfig`, based on [Local.xcconfig.example](Local.xcconfig.example).

## Make a focused change

1. Fork the repository and create a branch from `main` with a descriptive name.
2. For a behavior change, add a failing regression test using Swift Testing, then implement the smallest complete fix.
3. Reuse the app's existing controls, typography, and spacing. Include before/after screenshots for visual changes.
4. Update the relevant user documentation and planning entry when behavior changes.
5. Run the checks that apply to your change.

```sh
make test T=SuiteName
make format
make lint
make build
```

Run `make test` for changes that affect several areas. Tests use an isolated app host and must not access personal recordings, preferences, permissions, or the network. See [the testing strategy](planning/tdd-strategy.md) for the full workflow. Hardware capture and gesture behavior need manual verification; describe what you actually checked.

Documentation and asset-only changes do not need artificial unit tests. Check links, preview the result, and build the app when its bundled assets change.

## Open a pull request

Open your pull request against `main`. Explain the user-visible problem, the resulting behavior, and how you verified it. Keep unrelated refactoring separate. Mention any manual checks that still need another Mac or a physical device.

Use short, concrete issue reports: expected behavior, actual behavior, reproduction steps, macOS version, and the app version or commit. A small example project is especially useful for rendering and export problems. Use sample media and remove private information from shared recordings and logs.

## Design contributions

Show the interaction in context, including empty, selected, and disabled states when relevant. Keep the editor focused on the recording. Use the [brand assets](docs/brand/README.md) for AppShow's identity and the existing `AppShow/UI/` components for interface work.

## Attribution

Preserve upstream notices and dependency licenses. Include the source and terms for any new third-party assets or libraries. Discuss dependency additions before making them part of the build.

By contributing, you agree that your contributions will be licensed under the MIT License.
