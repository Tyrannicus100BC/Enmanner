# Enmanner

**Good Mac manners for local web apps.**

AI coding agents make it easy to build useful local web apps, but running one
on macOS is not. You have to open Terminal, remember the right commands, and
keep several services running.

Enmanner turns that routine into a lightweight Mac app. Double-click to start
your project; quit to stop it.

No terminal windows. No memorized commands. No wondering whether the app is
running.

Then keep building with your coding agent as usual. The Mac app keeps up as
your project changes.

## Add it to your project

You do not integrate Enmanner yourself. Open your project with a coding agent
that can edit its files and run commands, then paste this:

```text
Integrate Enmanner into this local web app using the instructions at
https://github.com/Tyrannicus100BC/Enmanner
```

The agent handles setup and verification, bringing product decisions back to
you. Enmanner is for human-facing web apps that run locally on one Mac, whether
they use one server or several services.

## Integration guide for coding agents

First decide whether the project is a good fit. Enmanner expects a
human-facing local web interface that should become a Mac application. A
headless API, proxy, worker, daemon, CLI, or infrastructure service is not a
fit unless the user explicitly wants a browser-facing front door for it.

For an integration, read and follow these in order:

1. `docs/integration-checklist.md`
2. the single-application or component-graph manifest guide selected there
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
the build accepts the modern source only when `actool` produces a verified
`IconImageStack`, and uses the legacy fallback otherwise. When capable modern
tooling is available, Enmanner rejects a directly
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

## Installer reference

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
or otherwise contact a Git remote. Review `targetScope` before installing. A
repository subdirectory, an enclosing Enmanner installation, or service-shaped
sibling repositories can require choosing the common workspace instead. Use
`--allow-subproject` only when the proposed nested target is intentionally the
complete user-facing app.

For a root Vite, Next.js, or Vinext project using npm, pnpm, Yarn, or Bun, the
installer can infer a safe loopback startup command, create
`enmanner/enmanner.json`,
append narrowly-owned managed sections to `.gitignore` and `AGENTS.md`, and
perform static validation. It reads an explicit `packageManager` field and
matching root lockfile evidence, refuses conflicting package-manager signals,
and only accepts tested direct `vite`, `next dev`, or `vinext dev` scripts. A
direct Express entry point can also be inferred when its package script,
`PORT`, `HOST`, and
`app.listen(PORT, HOST)` flow agree; that result remains explicitly marked as
requiring runtime verification. See
[docs/supported-toolchains.md](docs/supported-toolchains.md) for the exact
matrix and command contract.

The installer does not build the final app until a distinctive icon is
configured. Before icon work, `build-app --development` can produce a
separately named launcher with a `.development` bundle identifier and
conspicuous DEV icon; `test-app --development` records provisional native
lifecycle evidence. Neither the development artifact nor its receipt can
satisfy `doctor.complete`. Build output labels that bundle as an integration-test
artifact and identifies the ordinary `.app` as the finished launcher.

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
folders, and workspaces containing nested repositories. It reports a
`recommendedIntegrationRoot`, confidence, configuration durability, and whether
another product decision remains. For a high-confidence common workspace root,
an agent may pass `--allow-unversioned` as a mechanical acknowledgement without
asking the user again; the installation receipt records that durability choice.

Keep the Enmanner source checkout outside every candidate integration root. On
default macOS filesystems an `Enmanner/` checkout conflicts with the required
project-owned `enmanner/` configuration directory, and the installer refuses a
Git checkout at that path.

It also classifies `.enmanner` as `notInstalled`, `cacheOnly`, `incomplete`,
`legacyWithoutReceipt`, `installed`, or `damaged`. Cache-only build residue is removed
automatically. Use `--plan --replace-incomplete` to inspect an explicit,
recoverable replacement for other incomplete states; apply relocates the old
framework to a visible project-root backup before installing cleanly.

Installed framework provenance lives in `.enmanner/INSTALLATION.json`. Preview
or apply and fully verify the recorded upstream with:

```bash
./.enmanner/scripts/upgrade --check --latest
./.enmanner/scripts/upgrade --latest --verify
```

An explicit `--from /path/to/Enmanner` remains available for local and offline
development. The upgrade refuses all changes if a framework-owned file was
locally modified. It reports semantic versions and Git revisions, file changes,
schema and migration status, release notes, rebuild requirements, verification
evidence, and durable files awaiting commit. See `docs/upgrading.md` for the
focused routine-upgrade path.
The provenance also records exact file checksums, the upstream commit and dirty
state, the declared distribution URL, the observed checkout URL, provenance
confidence, whether the manifest was inferred, and which fields came from that
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
Use `./.enmanner/scripts/validate --runtime --json` for the normal bounded
machine-readable lifecycle result. Use `--json-lines` only while actively
diagnosing a longer check and consuming its newline-delimited progress. After
building, run
`./.enmanner/scripts/test-app --json`; its build-matched receipt lets `doctor`
report native-launch evidence instead of inferring success from bundle
existence.
After the icon has been reviewed, agents may run
`./.enmanner/scripts/finish-integration --runtime --json` to execute final
lifecycle validation, build, native testing, and doctor reporting in one
machine-readable result. The explicit runtime flag preserves the state-change
opt-in.
Doctor groups historical provenance under `installationHistory` and live
configuration/integration state under `currentStatus`, reports per-surface
agent-instruction state, and reports installed, configured, lifecycle,
development-native, presentation, final-native, and repository-ready
milestones. Local technical completion remains distinct from repository
recording, which Enmanner never performs automatically. Use
`./.enmanner/scripts/doctor --next` for a tailored Markdown summary of remaining
actions and relevant focused guidance.
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

Ask the coding agent to inspect the generated manifest rather than editing
low-level settings yourself. A self-contained one-process app uses the compact
[application manifest guide](docs/manifest-application.md); multi-process and
dependency-aware apps use the full [component-graph reference](docs/manifest.md).

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
60 seconds opens the circuit breaker. Enmanner opens a page after readiness on
each fresh app launch, but never opens another page during automatic recovery.
Choose **Window → Runtime Logs** or press **Command-Shift-L** to inspect the
bounded live output while the app is starting, healthy, reconnecting, or
failed. Filter by component when a database or other service is noisy; hiding
its output does not stop supervision. A selected managed service can be
restarted with its affected dependants from that window. Failure surfaces offer
**Copy for Coding Agent**, which packages the project path, failed component,
resolved command, allocated ports, and bounded logs into a paste-ready handoff.
Logs remain memory-only and are not archived to disk.

Stateful projects may declare advisory launch guards for stable ports or open
data paths, and may expose one project-owned backup command as **File → Back Up
Now**. Enmanner supervises that command and remembers the last successful run;
the project continues to own backup format, destination, retention, and restore.

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

Enmanner was created by James Marr in close collaboration with Codex, OpenAI's
coding agent. Agents are customers of the framework too, and their constraints,
concerns, and experience deserve serious design attention.

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
