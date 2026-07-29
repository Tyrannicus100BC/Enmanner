# Enmanner

Enmanner is an early, open-source macOS launcher for local web applications. It is
for people who can describe the app they want to an AI coding agent but should
not have to learn about terminals, ports, server processes, package managers,
or native application bundles.

The idea is simple:

> The repository is the source of truth. The `.app` is the front door.

Enmanner adds transparent source files to a project, then builds a small native Mac
app beside it. Opening that app starts the project's local server, waits until
it is ready, and either presents the web interface in a normal WKWebView window
or opens it in the default browser. In external-browser mode the launcher stays
in the Dock without showing a window during a healthy launch. The launcher
captures logs, explains startup failures, supervises the server, recovers after
restarts, and stops the server when the app quits. Generated apps also provide
standard macOS menus, keyboard shortcuts, a small Settings window, and normal
windowless/reopen behavior.

Enmanner is an MVP, not a universal application platform. It currently targets one
local server, one user, one Mac, and projects that already contain the runtime
needed by their startup command.

## What stays where

```text
Your Project/
├── source and dependencies       editable source of truth
├── project-owned local data      explicit and Git-ignored
├── enmanner.json                     project configuration
├── .enmanner/                        tracked launcher source and guidance
└── Your Project.app              small reproducible wrapper, Git-ignored
```

The `.app` does not contain the source repository, `node_modules`, databases,
uploads, or arbitrary project files. Dependencies stay with the project. Enmanner
does not create a registry or a large hidden workspace in Application Support.
Deleting the project folder deletes the project and its launcher.

## Requirements

- macOS 13 or newer
- Apple Command Line Tools with Swift Package Manager
- the runtime already used by the application (Node for the included example)

No paid Apple Developer Program account, Homebrew package, global npm package,
`sudo`, or shell-profile change is required. The app is ad-hoc signed locally
when `codesign` is available. Modern Icon Composer `.icon` packages additionally
require a current full Xcode installation so Enmanner can compile them with
`actool`. When that tool is available, Enmanner rejects a directly configured
legacy `.icns` by default to prevent the Tahoe compatibility enclosure ("icon
jail"). Legacy icons remain a warned fallback on Command Line Tools-only
machines, with `--allow-legacy-icon` available for an intentional exception.

## Try the included Vite example

From a clean clone:

```bash
cd examples/vite-example
npm ci
./.enmanner/scripts/build-app
open "Enmanner Vite Example.app"
```

Then edit `src/main.js`. Vite's own HMR updates the native window; the `.app`
does not need to be rebuilt. To verify the full server lifecycle without
opening the app:

```bash
./.enmanner/scripts/validate --runtime
```

The runtime check starts the configured server on an Enmanner-selected loopback
port, waits for it, then stops it. It can mutate project runtime state; inspect
databases, container volumes, and service ownership before running it.

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

For a root npm/Vite project, the installer can infer a safe loopback startup
command, create `enmanner.json`, append narrowly-owned managed sections to
`.gitignore` and `AGENTS.md`, perform static validation, and build the `.app`.
For other stacks it reports candidate package scripts but stops with
`configurationRequired`; it never builds a knowingly provisional manifest.
Use `--name` and `--identifier` to override inferred presentation values.
Pass `--runtime` to opt into a real start/stop cycle after reviewing state
ownership.

The plan classifies repository roots, repository subdirectories, unversioned
folders, and workspaces containing nested repositories. A workspace containing
sibling repositories needs an explicit choice: create a small launcher
repository at the workspace root, install in a designated existing repository,
or knowingly keep the launcher configuration unversioned.

Installed framework provenance lives in `.enmanner/INSTALLATION.json`. Check or
apply an update from an Enmanner checkout with:

```bash
./.enmanner/scripts/upgrade --check --from /path/to/Enmanner
./.enmanner/scripts/upgrade --apply --from /path/to/Enmanner
```

The upgrade refuses all changes if a framework-owned file was locally modified.
The provenance also records exact file checksums, the upstream commit and dirty
state, whether the manifest was inferred, and which fields came from that
inference. A published aggregate baseline allows an untouched 0.1.0
installation to enter the provenance-managed workflow safely.
Project-owned supervisor code belongs outside `.enmanner/`, or under the
reserved `.enmanner/project/` override directory. `install --repair` uses the
same conflict-aware mechanism.

Use `./.enmanner/scripts/doctor --json` for resolved executable, arguments,
working directory, effective GUI `PATH`, toolchain, icon capability, and
optional runtime evidence. Enmanner does not load `.env`; the project command
may do so explicitly. Remove local Swift products with
`./.enmanner/scripts/clean`; builds report both app and cache size.

For applications with several long-running components, Enmanner continues to
own one foreground command. Adapt the published
[project supervisor template](docs/project-supervisor.md) so service ownership
and signal handling remain explicit.

Before choosing embedded presentation for a browser-capability-heavy project,
use the [WKWebView compatibility checklist](docs/embedded-webview-checklist.md).

Ask the coding agent to inspect the generated manifest rather than editing
low-level settings yourself. The format is documented in
[docs/manifest.md](docs/manifest.md).

## What requires an app rebuild?

Ordinary web source, styles, server code, and local application data do not.
Rebuild after changing the display name, bundle identifier, icon, native window
configuration, or files in `.enmanner/launcher`.

## Failure and recovery behavior

The launcher starts the command directly without a shell or Terminal, captures
standard output and error, and polls the configured HTTP readiness URL. If
initial startup fails, it shows a plain-language error with recent output,
copy/retry controls, and a way to reveal the project. If a previously-ready
server exits, Enmanner shows a reconnecting state and performs bounded restarts.

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
- `docs/roadmap.md` — intentionally deferred work
- `docs/known-limitations.md` — honest MVP boundaries
- `docs/future-validation.md` — decisions that need broader Mac testing

## Contributing

Run:

```bash
swift test --package-path integration/launcher
./tests/smoke-vite-example
```

Keep the launcher dependency-free, preserve argument-array process launching,
and record significant lifecycle or storage tradeoffs in the architecture
document.
