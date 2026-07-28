# Architecture

## The project folder is the application

Enmanner installs source into `.enmanner/` and keeps project-owned configuration in
`enmanner.json`. The native bundle is assembled beside those files and locates the
manifest by taking the parent directory of its own bundle URL. It stores no
absolute project registration. Moving the whole folder therefore preserves the
relationship; rebuilding handles any macOS signature or metadata changes.

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
  (or copies a legacy `.icns`), and ad-hoc signs locally.

SwiftPM has no non-Apple dependencies. The package targets macOS 13, a practical
baseline for structured concurrency and current WKWebView behavior while
retaining several years of Mac coverage.

## Startup sequence

1. Resolve the project as the app bundle's parent.
2. Decode `enmanner.json` and reject invalid version, paths, identifiers, public
   readiness hosts, obvious embedded secrets, or global-install flags.
3. Try the optional preferred loopback port, otherwise bind a loopback socket
   to port zero, and retain the selected port number.
4. Expand only `${ENMANNER_PORT}` and `${ENMANNER_PROJECT_DIR}`.
5. Resolve a relative executable path from `server.workingDirectory`, an
   absolute executable directly, or a bare executable name from a GUI-safe PATH
   made from the inherited value plus standard Apple Silicon and Intel local
   runtime locations.
6. Start `Process` in the validated project-relative working directory.
7. Put the immediate child in its own process group and capture both pipes.
8. In embedded mode, display the native starting state. External mode remains
   windowless while keeping its normal Dock presence.
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
external mode exposes it if the user reopens the Dock app. Each restart uses the
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

## Browser lifecycle and navigation

Embedded mode uses a persistent WKWebView with the default website data store.
The main interface remains hidden until readiness. User-activated links to
other hosts and links requesting a new window open in the default browser.
Server restarts hide the broken page and reload only after readiness returns.

External mode keeps the launcher in the Dock but does not show a native window
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
Embedded browser commands add Back, Forward, Reload, Stop, and page zoom.

The Settings window currently stores a small set of native preferences in
`UserDefaults`: embedded page zoom, external-link handling, and whether failure
details include recent server output. These are launcher preferences only; a
future manifest extension can describe project-owned settings without putting
runtime data in the generated app bundle.

## Failure UI and logs

The native state panel distinguishes starting, reconnecting, running externally,
and failed. Embedded mode presents it during startup. External mode presents it
only after an explicit Dock reopen or when a failure needs attention. Failure
includes the configured argument array, exit status when known, and recent
output. Users can show the bounded log view, copy it, retry, or reveal the
project without opening Terminal.

Logs are memory-only and capped at 500 entries. Enmanner does not create a hidden
log archive or leak project output into Application Support.

## Storage and trust

The MVP prefers explicit, Git-ignored project data directories. Small native
window preferences may be stored by macOS through normal autosave behavior, but
Enmanner has no registry and no large Application Support workspace. Future secret
management should use Keychain. `.env` is supported only as an application
compatibility fallback and is ignored by the installer.

Enmanner executes repository code as the current user. It validates configuration
boundaries but does not sandbox code, inspect package supply chains, or grant
additional permissions.

## Build and signing

Apple Command Line Tools provide `swift`, the macOS SDK, `plutil`, and
`codesign`, so full Xcode is not required when no icon or a legacy `.icns` is
configured. Modern Icon Composer `.icon` packages require a current full Xcode
installation because Enmanner compiles them with `actool`. The result includes an
asset catalog image stack and `CFBundleIconName`, plus an `.icns` fallback. The
script uses an ad-hoc signature because it is useful for stable local bundle
identity and needs no account. Gatekeeper behavior across OS releases and moved
bundles still needs testing on a broader Mac matrix.

Ordinary web edits do not alter the bundle. Display name, identifier, icon,
window configuration, launcher source, or native metadata changes do require a
rebuild.

## Why there is no reverse proxy

Vite accepts an injected strict port and handles HMR correctly against the same
loopback origin. Generic servers can do the same. A launcher-owned reverse proxy
would add connection, WebSocket, security, and failure semantics without being
needed for the first vertical slice. It remains an option if broad framework
testing reveals that stable-origin recovery cannot be achieved otherwise.
