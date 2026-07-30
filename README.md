# Enmanner

Enmanner is an early, open-source macOS launcher for local web applications. It is
for people who can describe the app they want to an AI coding agent but should
not have to learn about terminals, ports, server processes, package managers,
or native application bundles.

The idea is simple:

> The repository is the source of truth. The `.app` is the front door.

Enmanner adds a transparent, project-local framework distribution, then builds a
small native Mac app beside it. Opening that app starts the project's local
server, waits until it is ready, and opens it in the default browser. An
opt-in embedded WKWebView presentation is available for applications that pass
its compatibility checklist. In browser mode the launcher stays in the Dock
without showing a window during a healthy launch. The launcher
captures logs, explains startup failures, supervises the server, recovers after
restarts, and stops the server when the app quits. Generated apps also provide
standard macOS menus, keyboard shortcuts, a small Settings window, a live
Server Log window, and normal windowless/reopen behavior.

Enmanner is an MVP, not a universal application platform. It currently targets one
local server, one user, one Mac, and projects that already contain the runtime
needed by their startup command.

Today, the coding agent is part of the product architecture: Enmanner is a
packaging and lifecycle protocol that helps an agent turn a local web project
into a well-behaved Mac app for normal human use.

## Agent fast path

First decide whether the project is a good fit. Enmanner expects a
human-facing local web interface that should become a Mac application. A
headless API, proxy, worker, daemon, CLI, or infrastructure service is not a
fit unless the user explicitly wants a browser-facing front door for it.

For an integration, read and follow these in order:

1. `docs/integration-checklist.md`
2. `docs/manifest.md`
3. the installed project's `.enmanner/AGENTS.md`

Only `integration/scripts/install` is run from this Enmanner checkout. After
installation, run validation, icon, doctor, and build commands from the target
project through `./.enmanner/scripts/...`.

## What stays where

```text
Your Project/
├── source and dependencies       editable source of truth
├── project-owned local data      explicit and Git-ignored
├── enmanner/                     project-owned integration
│   ├── enmanner.json             versioned configuration
│   ├── start                     optional foreground supervisor
│   └── icon/                     icon package and source artwork
├── .enmanner/                    tracked framework-owned distribution
│   ├── scripts/                  stable public commands
│   ├── framework/                native Package.swift and Sources
│   ├── instructions/             agent compatibility guidance
│   └── templates/                copy out before customization
└── Your Project.app              small reproducible wrapper, Git-ignored
```

The `.app` does not contain the source repository, `node_modules`, databases,
uploads, or arbitrary project files. Dependencies stay with the project. Enmanner
does not create a registry or a large hidden workspace in Application Support.
Deleting the project folder deletes the project and its launcher.

Both Enmanner directories are deliberately documented and generated in
lowercase. Keeping that single spelling makes the same repository portable to
case-sensitive environments without adding repository-style detection.

## Requirements

- macOS 13 or newer
- Apple Command Line Tools with Swift Package Manager
- the runtime already used by the application (Node for the included example)

No paid Apple Developer Program account, Homebrew package, global npm package,
`sudo`, or shell-profile change is required. The app is ad-hoc signed locally
when `codesign` is available. Modern Icon Composer `.icon` packages additionally
require a current full Xcode installation so Enmanner can compile them with
`actool`. Shared projects may configure both `icon.modern` and `icon.legacy`;
the build selects the modern source when `actool` is available and the legacy
fallback otherwise. When that tool is available, Enmanner rejects a directly
configured legacy `.icns` by default to prevent the Tahoe compatibility
enclosure ("icon jail"). Legacy icons remain a warned fallback on Command Line
Tools-only machines, with `--allow-legacy-icon` available for an intentional
exception.

## Try the included Vite example

From a clean clone:

```bash
cd examples/vite-example
npm ci
./.enmanner/scripts/build-app
open "Enmanner Vite Example.app"
```

Then edit `src/main.js`. Vite's own HMR updates the browser; the `.app`
does not need to be rebuilt. To verify the full server lifecycle without
opening the app:

```bash
./.enmanner/scripts/validate --runtime
```

The runtime check starts the configured server on an Enmanner-selected loopback
port, waits for the full graph, observes all managed services for five seconds,
then stops it. It can mutate project runtime state; inspect databases,
container volumes, and service ownership before running it.

## Add Enmanner to an existing project

This repository's installer copies normal tracked files into the target. It
does not copy Enmanner's Git history or create a nested repository.

```bash
./integration/scripts/install "/path/to/Your Project"
```

Preview an installation before changing the project:

```bash
./integration/scripts/install --plan "/path/to/Your Project"
./integration/scripts/install --plan --json "/path/to/Your Project"
```

The plan performs local filesystem and Git inspection only. Its `ahead` and
`behind` values come from existing local remote-tracking refs; it does not fetch
or otherwise contact a Git remote.

For a root Vite or Next.js project using npm, pnpm, Yarn, or Bun, the installer
can infer a safe loopback startup command, create `enmanner/enmanner.json`,
append narrowly-owned managed sections to `.gitignore` and `AGENTS.md`, and
perform static validation. It reads an explicit `packageManager` field and
matching root lockfile evidence, refuses conflicting package-manager signals,
and only accepts tested direct `vite` or `next dev` scripts. See
[docs/supported-toolchains.md](docs/supported-toolchains.md) for the exact
matrix and command contract.

The installer does not build the final app until a distinctive icon is
configured. Before icon work, `build-app --development` can produce a
separately named launcher with a `.development` bundle identifier and
conspicuous DEV icon; `test-app --development` records provisional native
lifecycle evidence. Neither the development artifact nor its receipt can
satisfy `doctor.complete`.

For other stacks it reports candidate package scripts, installs the framework,
and stops with `configurationRequired`. It writes
`enmanner/enmanner.json.example` with the requested name and identifier,
candidate command, deterministic preferred port, and unresolved compatibility
checks; it never treats that draft as the live manifest or builds a knowingly
provisional app.
Use `--name` and `--identifier` to override inferred presentation values.
Pass `--runtime` to opt into a real start/stop cycle after reviewing state
ownership. When an icon is already configured and installation builds the app,
that opt-in also runs the final generated-app lifecycle test. Without an icon,
the opt-in builds and tests the development-only app while the result remains
`iconRequired`. A final build without a matching `test-app` receipt reports
`nativeLaunchVerificationRequired`.

The plan classifies repository roots, repository subdirectories, unversioned
folders, and workspaces containing nested repositories. A workspace containing
sibling repositories needs an explicit choice: install in a designated
existing repository, or knowingly keep the launcher configuration unversioned
by passing `--allow-unversioned`.

Installed framework provenance lives in `.enmanner/INSTALLATION.json`. Check or
apply an update from an Enmanner checkout with:

```bash
./.enmanner/scripts/upgrade --check --from /path/to/Enmanner
./.enmanner/scripts/upgrade --apply --from /path/to/Enmanner
```

The upgrade refuses all changes if a framework-owned file was locally modified.
The provenance also records exact file checksums, the upstream commit and dirty
state, the upstream repository URL when available, whether the manifest was
inferred, and which fields came from that
inference. Every file inside `.enmanner/` is framework-owned. The manifest,
optional supervisor, icon package, and icon artwork stay in the visible
project-owned `enmanner/` sibling. Other application data and scripts remain in
their ordinary project paths. `install --repair` uses the same conflict-aware
mechanism.

Use `./.enmanner/scripts/doctor --json` for resolved executable, arguments,
working directory, effective GUI `PATH`, installation provenance, draft
manifest state, generated-app ownership, managed-file state, icon capability,
and optional runtime evidence. Enmanner does not load `.env`; the project
command may do so explicitly. Remove local Swift products with
`./.enmanner/scripts/clean`; builds report both app and cache size.
Use `./.enmanner/scripts/validate --runtime --json-lines` for newline-delimited
progress during longer lifecycle checks. After building, run
`./.enmanner/scripts/test-app --json`; its build-matched receipt lets `doctor`
report native-launch evidence instead of inferring success from bundle
existence.
Doctor groups historical provenance under `installationHistory` and live
configuration/integration state under `currentStatus`, reports per-surface
agent-instruction state, and shows the evidence behind completion. The former
flat status fields remain as deprecated compatibility aliases for one release.
Use `./.enmanner/scripts/build-app --json` when the final artifact path, icon
packaging, signing, replacement, and size evidence must be machine-readable.

The intended integration order is documented in
[docs/integration-checklist.md](docs/integration-checklist.md). In short:
configure and validate lifecycle behavior, optionally prove it through the
development-only native bundle, create and preview the icon, then build and
test the finished app.

For applications with several runtime components, declare services, one-shot
tasks, observed prerequisites, named endpoints, and explicit dependencies in
the manifest. Services use explicit readiness, including process-uptime
readiness for workers. Startup tasks may expose temporary endpoints and finish
through a completion probe. The single-process `application` shorthand lowers
into that same component graph.

Before choosing embedded presentation for a browser-capability-heavy project,
use the [WKWebView compatibility checklist](docs/embedded-webview-checklist.md).

Ask the coding agent to inspect the generated manifest rather than editing
low-level settings yourself. The format is documented in
[docs/manifest.md](docs/manifest.md).

Projects may declare a curated set of local dotenv values for the native
Settings window. On first launch, Enmanner materializes the configured `.env`
from `.env.example` before starting the server. If required declared values are
blank, it opens Project Settings and waits instead of launching a server that is
known to be misconfigured. Secret fields can be temporarily revealed for
verification. Enmanner preserves unrelated dotenv content and restarts the
server after saving.
Values remain in the Git-ignored project file so existing dotenv loaders, unit
tests, and direct development commands keep the same behavior. Enmanner does
not infer or display every environment variable.

## What requires an app rebuild?

Ordinary web source, styles, server code, and local application data do not.
Rebuild after changing the display name, bundle identifier, icon, native window
configuration, or files in `.enmanner/framework`.

## Failure and recovery behavior

The launcher starts the command directly without a shell or Terminal, captures
standard output and error, and polls the configured HTTP readiness URL. If
initial startup fails, it shows a plain-language error with recent output,
copy/retry controls, and a way to reveal the project. If a previously-ready
service exits, Enmanner restarts it and its affected dependants with bounded
backoff while leaving unrelated components running. More than five failures in
60 seconds opens the circuit breaker. Browser mode opens a page automatically
only on initial launch, never on recovery.
Choose **Window → Server Log** or press **Command-Shift-L** to inspect the
bounded live output while the app is starting, healthy, reconnecting, or
failed. Logs remain memory-only and are not archived to disk.

Enmanner runs project code with the current user's permissions. It is not a
sandbox. Servers are loopback-only by default and the validator rejects public
readiness hosts, path traversal, obvious secrets, and global-install flags.

## Sharing today

Share the Git repository or a source ZIP, not the generated binary. The
recipient opens the source with Codex or Claude Code, lets the agent install
project dependencies, and locally builds the `.app`. Polished export,
notarization, and distribution to other machines are future work.

## Project map

- `integration/` — files installed into a project as `.enmanner/`
- `examples/vite-example/` — working demonstration
- `docs/architecture.md` — launcher and lifecycle design
- `docs/philosophy.md` — product values
- `docs/agent-guidance.md` — instruction-package design
- `docs/continued-development-study.md` — post-integration agent study protocol
- `docs/roadmap.md` — intentionally deferred work
- `docs/known-limitations.md` — honest MVP boundaries
- `docs/future-validation.md` — decisions that need broader Mac testing

## Contributing

Run:

```bash
swift test --package-path integration/framework
./tests/install-workflows
./tests/package-manager-arguments
./tests/smoke-vite-example
./tests/smoke-toolchain-adapters
```

Keep the launcher dependency-free, preserve argument-array process launching,
and record significant lifecycle or storage tradeoffs in the architecture
document.
