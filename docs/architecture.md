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
- `EnmannerLauncher` is a direct AppKit shell around WKWebView. Direct AppKit keeps
  lifecycle ownership explicit and avoids a SwiftUI state bridge for a small
  window.
- `enmanner-validator` reuses the exact core types for script-facing static and
  runtime validation.
- `build-app` compiles in release mode, creates a conventional app bundle with
  `plutil`, compiles a configured Icon Composer `.icon` package with `actool`
  (or explicitly falls back to a legacy `.icns`), verifies the modern icon
  metadata and image stack, ad-hoc signs locally, and verifies the signature.
  It embeds an ownership marker and refuses to replace a same-named app that it
  cannot attribute to the current bundle identifier.
- `build-app --development` uses the same launcher but creates a separately
  named sibling bundle with a `.development` identifier, explicit development
  ownership metadata, and a conspicuous framework-generated DEV icon. Its
  separate `test-app --development` receipt is diagnostic evidence only and
  cannot satisfy final integration completion.

The installed distribution includes `Package.swift` and `Sources`, but excludes
the framework's own tests and installer. SwiftPM has no non-Apple dependencies.
The package targets macOS 13, a practical baseline for structured concurrency
and current WKWebView behavior while retaining several years of Mac coverage.

## Startup sequence

1. Resolve the project as the app bundle's parent.
2. Decode `enmanner/enmanner.json` and reject invalid version, paths,
   identifiers, public readiness hosts, obvious embedded secrets, or
   global-install flags.
3. Try the optional preferred loopback port, otherwise bind a loopback socket
   to port zero, and retain the selected port number.
4. Expand only `${ENMANNER_PORT}` and `${ENMANNER_PROJECT_DIR}`.
5. Resolve a relative executable path from `server.workingDirectory`, an
   absolute executable directly, or a bare executable name from a GUI-safe PATH
   made from the inherited value plus standard Apple Silicon and Intel local
   runtime locations.
6. Start `Process` in the validated project-relative working directory.
7. Put the immediate child in its own process group and capture both pipes.
8. In browser mode, the default, remain windowless while keeping the normal Dock
   presence. Embedded mode displays the native starting state.
9. Poll HTTP readiness, then load the URL in WKWebView or ask the default browser
   to open it.

The port-selection socket is closed before launch. This leaves a small
allocation race, but `--strictPort` makes the Vite example fail clearly rather
than silently choosing a mismatched port. A preferred port provides a stable
browser origin when available; a launcher-owned reservation or proxy would be
more complex and is deferred.

## Process lifecycle

The launcher retains the `Process` and marks intentional shutdown separately
from unexpected exit. Closing the last window leaves either mode running
without a window. On Quit (including Command-Q) or retry it sends `SIGTERM` to
the process group, waits up to two seconds, then sends `SIGKILL` to that group.
This covers common package-manager descendants without starting through a
shell. There is still no complete guarantee for children that deliberately
escape the process group.

An exit before first readiness produces a failure screen. An exit after the app
has been ready enters a reconnecting state and performs up to five restarts with
bounded exponential backoff. Embedded mode displays that state immediately;
browser mode exposes it if the user reopens the Dock app. Each restart uses the
same selected port, polls readiness, and reloads the embedded page. Framework
HMR remains untouched while the server stays up.

The bundle also declares that Launch Services should prohibit multiple
instances. Normal repeated opens therefore activate the existing app instead of
starting a second project server.

Readiness accepts redirects and transient connection errors. Each request has a
short timeout; the overall deadline comes from the manifest.

Runtime validation races readiness against process exit. A server that exits
before readiness therefore fails immediately with its status and bounded recent
output instead of consuming the rest of the readiness timeout. It is an
explicitly state-changing operation: Enmanner cannot infer whether a project
command mutates databases, containers, volumes, or caches.
The validator also handles `SIGINT` and `SIGTERM`, stops the owned process group
with the same bounded escalation policy, and emits structured interruption
postconditions. Optional JSON Lines progress reports startup, readiness,
shutdown, and postcondition phases without changing the single-result JSON
mode.

After readiness, validation records the launched process tree, stops the
supervisor, and requires the immediate process to exit, its process group to
disappear, the readiness endpoint to remain unavailable, and the selected port
to have no loopback listener. It reports surviving tracked PIDs and the
Git-status delta as `gitStatusMutations`. The former `workspaceMutations` JSON
field remains as a deprecated compatibility alias for one release.
External containers, daemons, and deliberately detached processes remain
project-owned and are reported as outside the proof boundary.

## Browser lifecycle and navigation

Embedded mode uses a persistent WKWebView with the default website data store.
The main interface remains hidden until readiness. User-activated links to
other hosts and links requesting a new window open in the default browser.
Server restarts hide the broken page and reload only after readiness returns.

Browser mode keeps the launcher in the Dock but does not show a native window
during a healthy launch. Once readiness succeeds, it opens the same URL through
`NSWorkspace` in the default browser and continues to own the server. A Dock
click from another app foregrounds Enmanner so its menus, including Quit, are
available. Clicking the Dock icon again while Enmanner is already active reopens
the default browser. When the server is not ready, that second click reveals
the native status window instead.

## Native menus and settings

The launcher constructs conventional Application, File, Edit, View, Window,
and Help menus using the manifest name. Standard responder-chain actions cover
Undo, Cut, Copy, Paste, Select All, Close Window, Minimize, and Full Screen.
Embedded browser commands add Back, Forward, Reload, Stop, and page zoom. The
Window menu opens a dedicated live Server Log window in either presentation
mode without revealing Terminal.

The Settings window stores a small set of launcher preferences in `UserDefaults`:
embedded page zoom, external-link handling, and whether failure details include
recent server output. An optional manifest declaration adds project settings for
explicitly selected dotenv keys. Browser-mode projects present that form
directly instead of reserving a tab for embedded-browser preferences. The UI
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
and failed. Embedded mode presents it during startup. Browser mode presents it
only after an explicit Dock reopen or when a failure needs attention. Failure
includes the configured argument array, exit status when known, and recent
output. Users can show the bounded inline log view, copy it, retry, or reveal
the project without opening Terminal. A separate resizable Server Log window
remains available while the server is healthy, starting, reconnecting, or
failed and updates from the same in-memory buffer.

Logs are memory-only and capped at 500 entries. Enmanner does not create a hidden
log archive or leak project output into Application Support.

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
build verifies both the metadata and `IconImageStack`. When `actool` is present,
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
selected development or final bundle with a private test-status file and
browser suppression, verifies readiness, requests normal application quit, and
records a build-matched ignored receipt only after cleanup and port release.
Development and final receipts are separate; only the final receipt contributes
to completion.
`.enmanner/INSTALLATION.json` records the installed version, upstream commit,
and checksums of framework-owned files. Repair and upgrade operations refuse to
write when those files have local modifications. Every installed file is
framework-owned; there is no hidden project override area. The visible
project-owned `enmanner/` sibling contains configuration, optional supervisors,
icon packages, and icon source artwork. Application data and unrelated scripts
remain in their ordinary project paths.

## Why there is no reverse proxy

Vite accepts an injected strict port and handles HMR correctly against the same
loopback origin. Generic servers can do the same. A launcher-owned reverse proxy
would add connection, WebSocket, security, and failure semantics without being
needed for the first vertical slice. It remains an option if broad framework
testing reveals that stable-origin recovery cannot be achieved otherwise.
