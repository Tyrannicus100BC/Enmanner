# Architecture

## The project folder is the application

Enmanner installs a curated, framework-owned source distribution into
`.enmanner/` and keeps project-owned integration files in `enmanner/`. The
native bundle is assembled beside those directories and locates
`enmanner/enmanner.json` beneath the parent directory of its own bundle URL. It
stores no absolute project registration. Moving the whole folder therefore
preserves the relationship; rebuilding handles any macOS signature or metadata
changes.

The bundle contains only:

```text
Application.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/EnmannerLauncher
    └── Resources/
        ├── Assets.car           optional modern icon image stack
        └── AppIcon.icns         optional legacy icon or fallback
```

No source, dependencies, databases, uploads, Git metadata, or runtime cache is
embedded.

## Major components

- `EnmannerCore` owns manifest decoding and validation, controlled interpolation,
  path containment, free-port allocation, process configuration/supervision,
  bounded logs, and readiness polling.
- `EnmannerLauncher` is a direct AppKit shell. It opens the application in the
  default browser and keeps lifecycle ownership explicit without a SwiftUI
  state bridge for its small native status and settings windows.
- `enmanner-validator` reuses the exact core types for script-facing static and
  runtime validation.
- `build-app` compiles in release mode, creates a conventional app bundle with
  `plutil`, selects a configured Icon Composer `.icon` package when `actool` is
  available or a configured legacy `.icns` fallback when it is not, verifies
  the modern icon metadata and image stack, ad-hoc signs locally, and verifies
  the signature.
  It embeds an ownership marker and refuses to replace a same-named app that it
  cannot attribute to the current bundle identifier.
- `build-app --development` uses the same launcher but creates a separately
  named sibling bundle with a `.development` identifier, explicit development
  ownership metadata, and a conspicuous framework-generated DEV icon. Its
  separate `test-app --development` receipt is diagnostic evidence only and
  cannot satisfy final integration completion. Build output calls it an
  integration-test artifact and identifies the ordinary bundle as the finished
  app so the two siblings are not presented as interchangeable.

The installed distribution includes `Package.swift` and `Sources`, but excludes
the framework's own tests and installer. SwiftPM has no non-Apple dependencies.
The package targets macOS 13, a practical baseline for structured concurrency
while retaining several years of Mac coverage.

## Startup sequence

1. Resolve the project as the app bundle's parent.
2. Decode `enmanner/enmanner.json`, lower inline application shorthand into a
   normalized component graph, and reject invalid version, paths, identifiers,
   dependency cycles, hidden endpoint-reference edges, public endpoint hosts,
   obvious embedded secrets, or global-install flags.
3. Allocate every named endpoint, using fixed or preferred loopback ports where
   declared, and retain those values for the launcher session.
4. Expand only exact component endpoint references and
   `${project.directory}`.
5. Traverse the dependency graph. Observe prerequisites, run exit-gated or
   completion-gated tasks, and start foreground services after their
   dependencies are satisfied.
6. Resolve relative executables from each component's working directory,
   absolute executables directly, and bare executable names from a GUI-safe
   PATH made from explicit manifest search directories, the inherited value,
   and standard Apple Silicon and Intel local runtime locations. Home-relative
   manifest entries are expanded without a shell, and the same PATH reaches
   child processes.
7. Put each managed service in its own process group, label its captured output,
   and wait for its required HTTP, TCP, command, or process readiness probe.
8. Remain windowless while keeping normal Dock presence.
9. Once the configured application component is ready, ask the default browser
   to open its named HTTP endpoint.

Port-selection sockets are closed before launch. This leaves a small allocation
race for each allocated endpoint, but `--strictPort` makes the Vite example fail
clearly rather than silently choosing a mismatched port. Endpoint values remain
frozen for the launcher session. A launcher-owned reservation or proxy would be
more complex and is deferred. Preferred-port probes use address-reuse semantics
matching normal development servers so a recently closed HTTP connection in
`TIME_WAIT` does not move an application to a different browser origin. A live
listener or other incompatible owner still forces allocation of a fallback.

## Process lifecycle

The launcher retains a supervisor for every managed service and marks
intentional shutdown separately from unexpected exit. Closing the last window
leaves either mode running without a window. On Quit (including Command-Q) or
retry it stops services in reverse dependency order. Each supervisor sends
`SIGTERM` to its process group, waits up to two seconds, then sends `SIGKILL` to
that group. This covers common package-manager descendants without starting
through a shell. There is still no complete guarantee for children that
deliberately escape the process group.

Tasks receive the same independent process-group ownership. An ordinary task
must exit successfully and is not accepted if descendants remain. A task with a
`completion` probe may expose temporary endpoints; once the probe passes,
Enmanner stops the whole group and records the task as successful.

An exit before first readiness produces a component-attributed failure. After
the app has been ready, Enmanner restarts the failed component and its
transitive dependants in topological order. Unaffected branches and upstream
dependencies remain running; the visible application enters reconnecting state
only when its component is in the affected set. Endpoint allocations remain
stable. Recovery uses bounded exponential backoff and a rolling circuit
breaker: more than five unexpected exits within 60 seconds stops automatic
recovery. A successful readiness probe does not erase recent failures.
Framework HMR remains untouched while its service stays up.

The bundle also declares that Launch Services should prohibit multiple
instances. Normal repeated opens therefore activate the existing app instead of
starting a second project server.

Readiness accepts redirects and transient connection errors. Each request has a
short timeout; the overall deadline comes from the manifest.

Runtime validation races readiness against process exit. A service that exits
before readiness therefore fails immediately with its status and bounded recent
output instead of consuming the rest of the readiness timeout. Once the whole
graph is ready, validation observes every managed service for a five-second
soak by default before declaring readiness stable. `--soak-seconds` may adjust
that interval. It is an explicitly state-changing operation: Enmanner cannot
infer whether a project command mutates databases, containers, volumes, or
caches.
The validator also handles `SIGINT` and `SIGTERM`, stops the owned process group
with the same bounded escalation policy, and emits structured interruption
postconditions. Optional JSON Lines reports component start, labelled stdout
and stderr, probe progress, task completion, soak progress, exits, shutdown, and
postcondition phases without changing the single-result JSON mode. Runtime
failures carry a stable code, phase, component, resolved command, working
directory, exit status or timeout where applicable, and bounded recent logs.

After readiness, validation records every launched process tree, stops the
runtime, and requires every immediate process and process group to disappear,
the application endpoint to remain unavailable, and every Enmanner-owned port
to have no loopback listener. Fixed prerequisite ports are reported as observed
and are deliberately excluded from shutdown ownership checks. It reports
surviving tracked PIDs and the Git-status delta as `gitStatusMutations`. The former `workspaceMutations` JSON field
remains as a deprecated compatibility alias for one release.
External containers, daemons, and deliberately detached processes remain
project-owned and are reported as outside the proof boundary.

## Browser lifecycle

The launcher stays in the Dock but does not show a native window
during a healthy launch. Once initial readiness succeeds, it opens the URL
through `NSWorkspace` in the default browser and continues to own the server.
Automatic recovery never opens another browser window. A Dock click from
another app foregrounds Enmanner so its menus, including Quit, are available.
Clicking the Dock icon again while Enmanner is already active explicitly
reopens the default browser. When the server is not ready, that second click
reveals the native status window instead.

## Native menus and settings

The launcher constructs conventional Application, File, Edit, View, Window,
and Help menus using the manifest name. Standard responder-chain actions cover
Undo, Cut, Copy, Paste, Select All, Close Window, Minimize, and Full Screen.
The Window menu opens dedicated live Runtime Logs without revealing Terminal.
The combined view can be filtered to Enmanner or one runtime component while
all components remain supervised.

The Settings window stores whether failure details include recent server output
in `UserDefaults`. An optional manifest declaration adds project settings for
explicitly selected dotenv keys. The UI
supports text, revealable masked secrets, booleans, files, and directories.
Field descriptions wrap within at most two lines instead of truncating.
Secret reveal controls sit above the text inside their fields, disappear while
a value is visible, and remask when editing ends.
Launcher diagnostics and Save & Restart share a fixed footer. Saving updates
the project-owned dotenv file atomically and restarts the supervised process; no
values enter the generated app bundle or native preferences.

Before the first server launch, an explicitly configured missing dotenv file is
materialized from its template, or as an empty owner-only file when no template
exists. Installation does not create machine-local state. If declared required
values remain blank, the launcher opens Project Settings and waits rather than
starting a server known to be misconfigured.

## Failure UI and logs

The native state panel distinguishes starting, reconnecting, running in the browser,
and failed. It appears after an explicit Dock reopen or when a failure needs
attention. Failure
includes the failed component, resolved argument array, working directory,
exit status when known, and recent output. Users can show the bounded inline
log view, copy it, retry, or reveal the project without opening Terminal. A
separate resizable Runtime Logs window remains available while the server is
healthy, starting, reconnecting, or failed. Its combined view updates from the
shared rolling buffer; component views use independent bounded buffers so a
noisy peer cannot evict the failed component's diagnostic tail.

Logs are memory-only and capped at 500 entries for the combined view and for
each component. Enmanner does not create a hidden log archive or leak project
output into Application Support. Filtering hides noise without disabling
capture, preserving failure diagnostics.

Build and runtime-validation scripts inspect free space on the project
filesystem before doing expensive work. `doctor` reports available bytes and
the size of Enmanner's Swift build cache, with
`./.enmanner/scripts/clean` as the only automated cleanup path. Enmanner never
repairs or removes Docker volumes, container state, databases, or other
project-owned data.

## Storage and trust

The MVP prefers explicit, Git-ignored project data directories. Small native
window preferences may be stored by macOS through normal autosave behavior, but
Enmanner has no registry and no large Application Support workspace. Projects
may expose a curated set of local values through a project-owned dotenv file.
Secret fields are masked in native UI but intentionally retain normal dotenv
semantics so existing project commands and tests continue to work. Enmanner
rejects configured dotenv files already tracked by Git.

Enmanner executes repository code as the current user. It validates configuration
boundaries but does not sandbox code, inspect package supply chains, or grant
additional permissions.

## Build and signing

Apple Command Line Tools provide `swift`, the macOS SDK, `plutil`, and
`codesign`, so full Xcode is not required when no icon or a legacy `.icns` is
configured. Modern Icon Composer `.icon` packages require a current full Xcode
installation because Enmanner compiles them with `actool`. The result includes an
asset catalog image stack and `CFBundleIconName`, plus an `.icns` fallback. The
build verifies both the metadata and `IconImageStack`. A manifest may declare
both formats; the build prefers the modern source when `actool` is present and
automatically chooses the legacy source on Command Line Tools-only machines.
When `actool` is present,
a directly configured legacy `.icns` fails validation unless the caller uses
the explicit `--allow-legacy-icon` escape hatch; without `actool`, it remains a
warned compatibility fallback. The script uses an ad-hoc signature because it
is useful for stable local bundle identity and needs no account. Gatekeeper
behavior across OS releases and moved bundles still needs testing on a broader
Mac matrix.

The generated `Info.plist` includes purpose strings for Desktop, Documents,
Downloads, network-volume, and removable-volume access. These strings grant no
permission; they explain that project files live alongside the app if macOS
prompts after the project is opened from a protected location. Including every
supported location keeps the bundle portable when the whole project moves.

Ordinary web edits do not alter the bundle. Display name, identifier, icon,
window configuration, launcher source, or native metadata changes do require a
rebuild.

Final build output also provides a compact handoff: managed components,
observed prerequisites, the local source path, the boundary between Enmanner
recovery and project-provided source watching, the Runtime Logs location, Quit
ownership, and the same-Mac versus cross-machine movement contract. The
integration instructions require the agent to make project-specific reload
details explicit rather than guessing from a generic framework rule.

## Installation ownership and upgrades

The installer first builds a non-mutating, schema-versioned plan. Only
high-confidence adapters may generate a complete manifest; ambiguous projects
receive framework files, an inactive `enmanner/enmanner.json.example`, and a structured
`configurationRequired` result without an app build. Inferred manifests use a
deterministic preferred port derived from the bundle identifier, with the
normal allocated-port fallback.

A final app build is a finishing operation. Lifecycle validation and the
separate development app build can run without an icon, but the ordinary
`build-app` requires a configured distinctive icon. `test-app` launches the
selected development or final bundle with a private test-status file, browser
suppression, and a sanitized Finder-equivalent environment. It verifies two
readiness/quit cycles including an immediate relaunch, then records a
build-matched ignored receipt only after cleanup and port release.
Development and final receipts are separate; only the final receipt contributes
to completion.
`.enmanner/INSTALLATION.json` records the installed version, upstream commit,
declared distribution URL, observed checkout URL, provenance confidence, and
checksums of framework-owned files. Explicit provenance overrides and
distribution metadata take precedence over the checkout's Git remote. The
installer warns when source and target share Git metadata.

Planning classifies framework state as `notInstalled`, `cacheOnly`, `incomplete`,
`legacyWithoutReceipt`, `installed`, or `damaged`. Cache-only residue is removed
automatically because only documented build products qualify. Other incomplete
states require `--replace-incomplete`, which relocates the old framework to a
visible backup before a clean installation. Receipt-backed repair and upgrade
operations refuse to write when framework files have local modifications.
Every installed file is
framework-owned; there is no hidden project override area. The visible
project-owned `enmanner/` sibling contains configuration, icon packages, and
icon source artwork. Application data and unrelated scripts
remain in their ordinary project paths.

Doctor reports installed, configured, lifecycle, development-native,
presentation, final-native, and repository-ready milestones. Local integration
can be technically complete while repository recording remains a user-owned
action; overall completion requires both unless unversioned workspace
durability was explicitly recorded.

## Why there is no reverse proxy

Vite accepts an injected strict port and handles HMR correctly against the same
loopback origin. Generic servers can do the same. A launcher-owned reverse proxy
would add connection, WebSocket, security, and failure semantics without being
needed for the first vertical slice. It remains an option if broad framework
testing reveals that stable-origin recovery cannot be achieved otherwise.
