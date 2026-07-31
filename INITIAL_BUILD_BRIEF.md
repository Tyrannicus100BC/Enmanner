Build Enmanner: an AI-first macOS launcher for local web applications

You are building the first working version of an open-source project provisionally named Enmanner.

Enmanner is a lightweight, source-first macOS framework that turns a locally developed web application into something that behaves like a normal Mac application.

The target user is not an experienced developer. The target user is someone using an AI coding agent such as Codex or Claude Code to build a personal application for the first time.

They may be capable of saying:

Build me an app to track my household finances.

They should not need to understand:

* Terminal
* localhost
* ports
* package managers
* server processes
* process supervision
* browser reload behavior
* native application bundles
* code signing
* Git
* runtime dependencies

Enmanner should hide those details while preserving a transparent, source-first development model.

The user’s AI coding agent is effectively the developer. The human is primarily the product owner and end user.

⸻

Core philosophy

Enmanner is based on several principles.

1. The source repository is the application’s source of truth

The user’s project folder contains:

* application source
* Git history
* locally installed dependencies
* the Enmanner integration
* the generated .app
* optionally local application data

The generated .app is not the canonical artifact. It is a lightweight launcher and native wrapper generated from source.

The .app must not contain the active editable source repository during development.

The user should be able to open the project folder in Codex or Claude Code, make changes, and see the running Enmanner application update without rebuilding the native launcher for ordinary web application changes.

2. Enmanner is added to an application repository

Enmanner must work for both:

* a brand-new project created with Enmanner from the start
* an existing web application that is later made Enmanner-compatible

Do not assume the user’s repository was originally cloned from the Enmanner repository.

Enmanner should be installable as a directory inside an existing repository, provisionally:

.enmanner/

Do not create a nested Git repository inside the user’s project.

Framework files copied into .enmanner/ should become normal files tracked by the user’s top-level Git repository.

3. The .app should be minimal

The generated application bundle should contain only what is needed to:

* behave like a native macOS application
* show a Dock icon
* participate in normal application switching
* open the web interface in the default browser
* start and supervise the project’s local server
* display useful startup and failure states
* stop the server when the app quits
* reload or reconnect when the server restarts

The generated .app should locate the project relative to itself whenever possible.

The initial recommended layout is:

ExampleProject/
├── .git/
├── src/
├── package.json
├── node_modules/
├── .enmanner/
├── enmanner/
│   ├── enmanner.json
│   ├── start
│   └── icon/
└── Example Project.app

The .app lives beside the project source.

Avoid putting substantial data in:

~/Library/Application Support

Enmanner may use small preference files there if truly needed, but the first implementation should preferably require no project registry and no large hidden workspace.

Use:

* the project directory for project-owned files and dependencies
* ~/Library/Caches only for disposable, reproducible caches if needed
* macOS Keychain for secrets in future versions
* minimal standard macOS preferences for small launcher preferences if needed

4. No system-wide dependency installation

Enmanner must not require application dependencies to be installed globally.

Do not depend on:

* global npm packages
* Homebrew packages
* global Python packages
* modifications to the user’s shell configuration
* changes to the user’s global PATH

Application dependencies should remain inside the application repository.

The first version may assume the project already has the runtime required to start its server, provided the validation and error UI clearly explain what is missing.

Do not build a full language-runtime installer unless it is necessary for the first vertical slice.

5. Source-first trust model

The first version of Enmanner should be built from source on the user’s own Mac.

The user should not be required to download and trust an opaque precompiled .app.

The Enmanner launcher should be buildable without an Apple Developer Program account.

Prefer a design based on:

* Swift
* Swift Package Manager
* macOS Command Line Tools
* direct .app bundle assembly
* ad-hoc local signing if needed

Do not require a paid Apple developer account.

Do not optimize the first version for polished distribution to other machines.

Sharing a completed binary application is a future problem. The initial sharing model is:

Git repository or source ZIP
    ↓
recipient opens it with Codex or Claude Code
    ↓
agent installs dependencies
    ↓
agent locally builds the Enmanner `.app`

6. Enmanner teaches the AI agent good application behavior

Enmanner is not only a launcher.

It should also contain agent-facing instructions that help inexperienced users receive applications with sane technical behavior even when they do not know what to ask for.

The user will not know to request hot reload, process recovery, database migrations, safe handling of secrets, or resilient collaboration architecture.

Enmanner should provide concise, structured guidance to the coding agent.

Separate:

* required Enmanner compatibility rules
* recommended application practices
* optional future capabilities

Use the terms:

* MUST
* SHOULD
* MAY

The first version must include guidance covering at least:

* deterministic server startup
* foreground server processes
* loopback-only network binding
* hot monitoring of code changes
* browser reload or reconnection after changes
* useful readiness detection
* preservation of user data
* separation of source code and runtime data
* avoiding secrets in Git
* avoiding system-wide installation
* safe Git behavior
* future database guidance
* future collaboration warnings

⸻

Product definition

Enmanner should allow a project to produce a small native macOS .app that:

1. Starts the project’s local web server.
2. Waits for the server to become ready.
3. Opens the application in the user’s default browser.
4. Keeps the server process attached to the launcher.
5. Stops the server when the native app quits.
6. Shows useful native UI while starting.
7. Shows useful native UI when startup fails.
8. surfaces relevant process output without requiring Terminal.
9. recovers gracefully when the server process restarts.
10. keeps the browser endpoint available through managed server recovery.
11. allows ordinary source changes to appear without rebuilding the .app.
12. can be generated from source using a simple build script.

⸻

Initial MVP scope

Build a real vertical slice rather than a broad but incomplete framework.

The first version should target:

* macOS only
* Swift
* Swift Package Manager
* default-browser presentation
* one local web application at a time
* one child server process
* JSON configuration
* simple HTTP readiness checking
* standard output and standard error capture
* graceful shutdown
* basic restart handling
* development-time browser reload behavior
* local source build
* no Apple Developer Program requirement

The first demonstrator should work with a simple Vite application, but Enmanner’s core code should not hardcode Vite-specific assumptions where a generic command and readiness URL will suffice.

⸻

Non-goals for the first version

Do not implement these unless they are required to support the core vertical slice:

* App Store distribution
* Developer ID signing
* notarization
* automatic public sharing
* secure tunneling
* cloud deployment
* mobile companion apps
* multi-user collaboration
* user accounts
* cloud databases
* framework marketplaces
* automatic installation of Node, Bun, Python, or Homebrew
* universal package management
* a graphical code editor
* a replacement for Codex or Claude Code
* a general-purpose IDE
* a generic Electron replacement
* a full plugin marketplace
* a background system daemon
* automatic GitHub authentication
* automatic remote repository creation
* a central Enmanner app registry
* large files in Application Support
* a custom browser engine
* a full security sandbox for arbitrary code

Document these as future possibilities where appropriate, but keep the implementation focused.

⸻

Proposed repository structure

Use good judgment, but start with a structure similar to:

enmanner/
├── README.md
├── LICENSE
├── AGENTS.md
├── docs/
│   ├── architecture.md
│   ├── philosophy.md
│   ├── manifest.md
│   ├── agent-guidance.md
│   └── roadmap.md
├── integration/
│   ├── AGENTS.md
│   ├── VERSION
│   ├── enmanner.schema.json
│   ├── instructions/
│   │   ├── core.md
│   │   ├── development-server.md
│   │   ├── reload.md
│   │   ├── persistence.md
│   │   ├── security.md
│   │   └── collaboration.md
│   ├── launcher/
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   └── Tests/
│   └── scripts/
│       ├── build-app
│       ├── validate
│       └── install
├── examples/
│   └── vite-example/
└── tests/

The exact structure may differ if a cleaner SwiftPM layout suggests itself.

The important separation is:

* Enmanner framework source
* files installed into a user project
* generated .app
* example application
* agent-facing documentation
* automated tests

⸻

Installed project structure

When Enmanner is added to a user’s repository, aim for:

UserProject/
├── .git/
├── .gitignore
├── AGENTS.md
├── src/
├── package.json
├── package-lock.json
├── node_modules/
├── enmanner/
│   ├── enmanner.json
│   ├── start
│   └── icon/
├── .enmanner/
│   ├── VERSION
│   ├── AGENTS.md
│   ├── enmanner.schema.json
│   ├── instructions/
│   ├── framework/
│   ├── templates/
│   └── scripts/
└── User Project.app

The installer should not overwrite an existing root AGENTS.md.

Instead, it should either:

* append a clearly delimited Enmanner-managed section, or
* provide a snippet the coding agent can add safely

Prefer a structure where project-specific configuration is outside framework-owned source.

For example:

enmanner/enmanner.json

is project-owned, while:

.enmanner/framework/

is framework-owned.

Document which files may be edited by the project and which should be replaced only during Enmanner upgrades.

⸻

Manifest design

Create a small, explicit manifest named:

enmanner/enmanner.json

Keep it understandable to both humans and coding agents.

A starting design might be:

{
  "$schema": "../.enmanner/enmanner.schema.json",
  "version": 2,
  "name": "Household Finances",
  "identifier": "local.enmanner.household-finances",
  "server": {
    "command": ["npm", "run", "dev", "--", "--host", "127.0.0.1"],
    "workingDirectory": ".",
    "environment": {
      "PORT": "${ENMANNER_PORT}"
    },
    "readiness": {
      "url": "http://127.0.0.1:${ENMANNER_PORT}/",
      "timeoutSeconds": 30
    }
  },
  "window": {
    "width": 1200,
    "height": 800,
    "resizable": true
  }
}

This is illustrative. Improve it where necessary.

Manifest principles:

* deterministic
* explicit
* easy for an AI agent to generate
* easy to validate
* versioned
* no unnecessary framework-specific concepts
* command represented safely as an argument array where possible
* no shell parsing required for ordinary use
* support environment-variable interpolation controlled by Enmanner
* project-relative working directories
* loopback-only defaults
* clear validation errors

The generated app should be able to locate enmanner/enmanner.json relative to the .app.

Avoid storing an absolute path to the project unless needed as a fallback.

⸻

Native launcher requirements

Implement the launcher in Swift.

Prefer standard Apple frameworks and minimal external dependencies.

The launcher should provide the following behavior.

Application startup

When launched:

1. Resolve the .app bundle’s location.
2. Resolve the sibling project directory.
3. Load and validate enmanner/enmanner.json.
4. Select or allocate a local port if needed.
5. construct the child process environment.
6. start the configured server command.
7. capture standard output and standard error.
8. display a native startup window or loading state.
9. poll the readiness URL.
10. after readiness succeeds, open the application URL in the default browser.

Process supervision

The launcher must:

* retain ownership of the child process
* detect unexpected termination
* show a clear failure state
* avoid leaving orphaned server processes
* terminate the child process when the app exits
* attempt graceful termination before force-killing
* handle repeated launch and quit cycles
* prevent accidental duplicate server launches from one app instance where practical

Do not run the child process through Terminal.

Do not require a terminal window to remain open.

Logging

Capture:

* server standard output
* server standard error
* launcher lifecycle events
* readiness failures
* process exit status

Provide a simple in-app way to view or copy logs.

The log viewer does not need to be elaborate, but failures should be understandable without opening Terminal.

A startup error screen should include:

* a concise human-readable explanation
* the command that failed
* exit status if available
* recent output
* a copy button
* a retry button
* an option to reveal the project folder

Avoid exposing only raw stack traces.

Browser presentation

Open the application URL in the default browser after readiness. The native
launcher remains responsible for the server process.

It may show a small status window or menu item, but do not overbuild the UX.

⸻

Development reload behavior

The target user should not need to know how hot reload works.

Enmanner’s agent instructions must require that compatible applications monitor their source for changes.

The implementation should support two layers of reload behavior.

Layer 1: framework-native hot reload

If the application framework already provides hot module replacement or browser refresh, preserve it.

Do not interfere with Vite HMR.

Do not restart the native .app for ordinary source changes.

Layer 2: server restart recovery

When the child server exits and restarts, the launcher must recover it.

For the MVP, it is acceptable for the launcher to:

1. detect server loss
2. show a reconnecting state
3. wait for readiness
4. leave the existing browser page able to reconnect

A more sophisticated launcher-owned reverse proxy or WebSocket/SSE reload bridge may be designed in the architecture, but only implement it now if it simplifies the overall system rather than expanding scope.

The first version must prove that:

* frontend source edits appear through Vite HMR
* server restart does not leave the browser endpoint permanently unavailable
* once the server is ready again, the app recovers without requiring the user to quit and reopen the .app

⸻

Build system

The launcher should be buildable on a Mac using Apple’s command-line development tools without requiring an Apple Developer Program account.

Prefer:

* Swift Package Manager for compilation
* a transparent shell script for assembling the .app
* generation of Contents/MacOS
* generation of Contents/Info.plist
* icon copying when available
* ad-hoc signing only if useful or required

Provide a command similar to:

./.enmanner/scripts/build-app

The script should:

1. validate enmanner/enmanner.json
2. compile the launcher in release mode
3. assemble the .app
4. set the display name
5. set the bundle identifier
6. include the icon if configured
7. place the resulting .app at the project root
8. sign locally if appropriate
9. print a concise success message
10. return nonzero on failure

The generated .app must not embed:

* .git
* node_modules
* the source repository
* application databases
* arbitrary large project files

It should remain a small wrapper.

Ordinary web application source edits should not require rebuilding the .app.

Changes to these may require rebuilding:

* application display name
* icon
* native window configuration
* bundle identifier
* launcher source
* other bundle metadata

Document this distinction.

⸻

Installation into a project

Provide an installation script or documented agent procedure that copies Enmanner into an existing repository.

Do not leave Enmanner’s own .git directory nested inside the user’s repository.

The install flow should:

1. detect the project root
2. refuse to overwrite existing Enmanner files without a clear upgrade path
3. copy the integration files into .enmanner/
4. create an initial enmanner/enmanner.json
5. inspect common project files where practical
6. propose or infer a startup command
7. create or update .gitignore
8. avoid excluding enmanner/enmanner.json or framework source that should be tracked
9. exclude generated .app bundles
10. exclude Swift build output
11. build the launcher
12. validate startup
13. provide clear next steps

Do not assume the project is JavaScript-based.

The installer may have strong support for Vite first, while allowing manually configured generic commands.

⸻

Git behavior

Enmanner should encourage Git use for users who may not know Git exists.

Do not implement a full Git UI in the MVP.

Instead:

* include agent instructions recommending Git initialization
* recommend an initial commit before major work
* recommend commits after successful agent tasks
* recommend checkpoints before risky migrations
* ensure generated binaries and installed dependencies are ignored
* ensure source, manifest, lockfiles, migrations, and Enmanner integration files are tracked
* keep live databases, secrets, logs, uploaded files, and runtime caches out of Git by default

The agent guidance should frame Git in user-facing terms such as:

* history
* checkpoints
* restore
* undo a broken change

Do not require the user to understand:

* staging
* branches
* rebasing
* merge conflicts

For now, Codex or Claude Code will perform the Git operations.

Enmanner’s instructions should tell the agent to do so silently and conservatively when appropriate.

Never automatically overwrite uncommitted user work.

⸻

Secrets

Do not implement full Keychain integration unless it fits cleanly in the first version.

However, design for it and document the intended direction.

Agent instructions must say:

* never commit secrets
* do not put API keys in source files
* do not expose secrets in logs
* prefer macOS Keychain for future Enmanner-managed credentials
* treat .env as a compatibility fallback, not the ideal long-term design
* ensure .env and similar files are ignored by Git

Include Keychain integration in the architecture and roadmap.

⸻

Agent-facing instruction package

Create an agent instruction entry point at:

.enmanner/AGENTS.md

It should explain that Enmanner is already installed in the project and that the agent must preserve compatibility.

Keep the entry point concise and link to focused files.

Suggested instruction files:

.enmanner/instructions/core.md
.enmanner/instructions/development-server.md
.enmanner/instructions/reload.md
.enmanner/instructions/persistence.md
.enmanner/instructions/security.md
.enmanner/instructions/collaboration.md

Required compatibility guidance

The agent instructions should establish these MUST rules:

* The application must have one deterministic noninteractive startup command.
* The startup process must remain in the foreground.
* The server must bind to loopback by default.
* The server must respect an Enmanner-provided port.
* The application must expose a readiness URL.
* The application must monitor relevant code changes.
* Framework-native hot reload must remain enabled where available.
* Browser clients must recover after server restarts.
* Runtime data must not be stored inside generated build output.
* Secrets must not be committed.
* Project dependencies must not be installed system-wide.
* The generated .app must not become the editable source of truth.
* Changes to normal web source must not require rebuilding the .app.

Recommended application guidance

Use SHOULD rules for:

* SQLite as the default structured local database when appropriate
* plain files for small document-like datasets
* migrations stored in source control
* backups before destructive migrations
* import and export of user-owned data
* useful user-facing error messages
* stable record identifiers
* idempotent startup
* graceful shutdown
* preservation of user-entered state where practical
* avoiding unnecessary background daemons
* avoiding unnecessary cloud dependencies

Collaboration guidance

The collaboration instructions should explain that requests such as:

Let another person use this app.

must not be treated as simply changing the bind address to 0.0.0.0.

The agent should first distinguish:

* same-computer multi-user use
* local-network access
* remote hosted access
* realtime synchronization
* shared data ownership

It should consider:

* authentication
* authorization
* encryption
* conflict resolution
* backup strategy
* privacy
* financial or personal data exposure
* network threat model

Include the principle:

Treat collaboration as a product architecture change, not a networking toggle.

This can remain advisory in the MVP.

⸻

Validation

Create:

./.enmanner/scripts/validate

It should check as much as is practical:

* enmanner/enmanner.json exists
* manifest is valid
* required paths are inside the project
* startup command is present
* working directory exists
* bundle name is valid
* bundle identifier is plausible
* server is configured for loopback
* readiness URL is valid
* generated app location is known
* project is not accidentally placing source inside the .app
* obvious secrets are not configured in the manifest
* common global-install assumptions are not present
* expected build tools are available
* launcher can compile
* application can start and become ready

Separate static validation from runtime validation if helpful.

Produce clear errors with remediation guidance.

The validation output should be useful to both the human and the coding agent.

⸻

Example application

Create a minimal Vite example that demonstrates:

* installation of Enmanner inside a project
* a working enmanner/enmanner.json
* generated .app
* default-browser opening
* frontend hot reload
* server process supervision
* readiness detection
* server restart recovery
* log capture
* graceful shutdown

The example should be easy to run from a clean clone.

Document exactly how to:

1. install prerequisites
2. install project dependencies
3. build the Enmanner app
4. launch it
5. edit a source file
6. observe live reload
7. stop the server unexpectedly
8. observe recovery or a useful error state

⸻

Testing

Add automated tests where practical.

At minimum, test:

* manifest decoding
* manifest validation
* path resolution
* environment interpolation
* process command construction
* project-relative app resolution
* readiness polling
* child process termination
* malformed manifest handling

Use dependency injection or small abstractions so process launching and readiness checking can be tested.

Do not overabstract the codebase, but avoid putting all functionality into one Swift file.

Create a small integration test or scripted smoke test for the Vite example.

⸻

Documentation

Write documentation for both technical contributors and AI coding agents.

README

The README should clearly explain:

* what Enmanner is
* who it is for
* what problem it solves
* current MVP limitations
* local build requirements
* how to add Enmanner to a project
* how to build the .app
* how to launch it
* why source remains outside the .app
* why dependencies remain in the project
* why Enmanner avoids large Application Support storage
* how sharing works today
* how finished app export may work later

Use plain language.

Avoid presenting Enmanner as a mature universal platform before it is one.

Architecture document

Document:

* project folder as source of truth
* generated .app as lightweight wrapper
* relative path resolution
* child process lifecycle
* readiness checks
* browser lifecycle
* reload behavior
* storage policy
* trust model
* local code-signing assumptions
* future export and distribution implications

Philosophy document

Preserve the project’s opinionated values:

* AI should generate applications, not development chores.
* The user should not need a terminal.
* The coding agent is the developer.
* The repository should remain inspectable.
* Source should not be hidden inside opaque application bundles.
* Hidden system directories should be used minimally.
* Project dependencies should stay with the project.
* A local app should be easy to delete by deleting its project folder.
* Git should protect inexperienced users without requiring them to learn Git.
* The launcher should be replaceable and reproducible.
* Enmanner should make the correct behavior the easiest behavior.
* Normies should not be forced to make architectural decisions they do not understand.

⸻

User experience principles

Use these principles when making implementation choices.

No unnecessary user choices

Do not ask a beginner to choose:

* where dependencies should be installed
* how process supervision works
* whether HMR uses WebSockets
* which local port to use
* whether Git should be initialized
* where logs should live
* how the native wrapper locates source

Enmanner and the coding agent should choose sensible defaults.

Clear failures

When something breaks, the app should say something like:

Enmanner could not start the application server.

Then provide useful detail and actions.

It should not present only:

ECONNREFUSED

Source remains visible

An advanced user or coding agent should be able to inspect every meaningful component.

Do not introduce opaque generated binary blobs beyond the compiled native launcher.

Project-local by default

Prefer putting project-owned files in the project.

Avoid large hidden directories.

Avoid global state.

Avoid requiring an uninstall tool to remove a project.

Native enough, not maximal native complexity

The launcher should feel like a Mac app, but do not overinvest in native UI beyond what the MVP requires.

The web app is the main interface.

⸻

Important design questions to resolve during implementation

Investigate and document the answers to these questions while building.

1. Can the Swift launcher be compiled reliably using Command Line Tools without full Xcode?
2. What minimum macOS deployment version is sensible?
3. What is the cleanest SwiftPM structure for a small AppKit or SwiftUI launcher?
4. Is a small SwiftUI shell sufficient, or is direct AppKit control cleaner?
5. How should the build script assemble Info.plist, icons, and bundle metadata?
6. Is ad-hoc signing necessary for the local workflow?
7. What behavior occurs when an ad-hoc-signed app is moved within the same Mac?
8. How should the launcher terminate process trees rather than only the immediate child process?
9. How should Enmanner avoid orphaning package-manager child processes?
10. How should readiness polling handle redirects and transient errors?
11. How should it distinguish expected shutdown from crashes?
12. How should the launcher communicate server recovery to the browser?
13. Can the launcher use an automatically chosen port while still supporting Vite HMR correctly?
14. Is a launcher-owned reverse proxy necessary for a robust first version?
15. What manifest fields are truly required for the MVP?

Do not let these questions block the initial implementation indefinitely.

Choose the simplest robust path, document tradeoffs, and leave clear extension points.

⸻

Implementation approach

Work incrementally.

Phase 1: architecture and skeleton

* Create repository structure.
* Write initial architecture notes.
* Define manifest schema.
* Build a minimal Swift launcher that opens a fixed URL in the default browser.
* Add unit tests for manifest parsing.

Phase 2: process launch

* Resolve project path relative to .app.
* Read enmanner/enmanner.json.
* launch the configured process.
* capture output.
* terminate it on quit.

Phase 3: readiness and UI

* Add readiness polling.
* Add loading state.
* Add failure state.
* Add retry.
* Add basic logs view.

Phase 4: build script

* Compile launcher.
* assemble .app.
* generate Info.plist.
* place .app at project root.
* test local launch.

Phase 5: Vite example

* Add an example app.
* configure port injection.
* verify HMR.
* verify quit behavior.
* verify server recovery behavior.

Phase 6: installation and validation

* Add project installer.
* Add validate.
* add agent instruction package.
* document existing-project integration.

Phase 7: polish

* improve errors
* improve logs
* refine default-browser lifecycle behavior
* add tests
* tighten documentation
* remove unnecessary complexity

Keep the project runnable at the end of every phase.

⸻

Coding standards

* Prefer simple, readable Swift.
* Use strong types for manifest data.
* Avoid unnecessary third-party dependencies.
* Use structured concurrency where it improves clarity.
* Keep process supervision isolated from UI code.
* Keep readiness checking isolated from process launching.
* Treat file paths carefully.
* Avoid shell command strings when argument arrays are possible.
* Never interpolate untrusted manifest strings into a shell command.
* Validate all project-relative paths.
* Prevent path traversal outside the project where practical.
* Log lifecycle events consistently.
* Add comments for non-obvious macOS behavior.
* Write tests for behavior that can fail silently.
* Make scripts strict with set -euo pipefail.
* Quote shell paths correctly.
* Support spaces in project and application names.
* Support projects stored outside the user’s home directory.
* Avoid assuming /Applications.
* Avoid assuming a particular user shell.

⸻

Security baseline

This is not a complete sandbox, but establish sane defaults.

* Bind local servers to 127.0.0.1, not all interfaces.
* Do not use sudo.
* Do not modify global shell configuration.
* Do not install global packages.
* Do not expose the local server publicly.
* Do not log secrets.
* Do not place secrets in the manifest.
* Treat project configuration as untrusted input.
* Avoid executing commands through /bin/sh -c unless absolutely necessary.
* Prefer executable plus argument arrays.
* Validate working directories.
* Avoid allowing the manifest to silently run outside the project.
* clearly document that Enmanner runs project code with the current user’s permissions.
* Do not falsely claim the application is sandboxed.

⸻

Acceptance criteria

The MVP is successful when all of the following are true.

1. A clean Vite example repository contains Enmanner under .enmanner/.
2. Running one documented build command creates a small .app beside the source.
3. The build does not require a paid Apple developer account.
4. Double-clicking the .app starts the Vite server without Terminal.
5. The app shows a native loading state.
6. The app opens the Vite UI in the default browser.
7. Editing frontend source causes the visible app to update through Vite HMR.
8. Quitting the .app terminates the server process.
9. A failed startup produces a useful native error screen.
10. Server output can be viewed and copied from the app.
11. The generated .app does not contain the project source or node_modules.
12. The project can be moved as a folder and rebuilt.
13. The launcher resolves the project relative to itself.
14. The project does not require large files in Application Support.
15. The repository includes clear agent instructions.
16. The repository includes guidance for Git, persistence, security, and future collaboration.
17. An existing Vite project can adopt Enmanner without reorganizing its entire repository.
18. There is no nested .git repository after installation.
19. Spaces in project names and paths work.
20. The implementation and documentation are honest about current limitations.

⸻

Deliverables

Produce:

* a working Swift launcher
* a versioned enmanner/enmanner.json manifest
* a JSON schema
* an app bundle build script
* a project installation script or agent-driven install procedure
* a validation script
* an example Vite project
* unit tests
* a smoke test
* README.md
* AGENTS.md
* focused agent instruction files
* architecture documentation
* philosophy documentation
* roadmap documentation
* a concise list of known limitations
* a concise list of decisions that require future validation

⸻

How to work

First inspect the repository and determine what already exists.

Then:

1. Write a concise implementation plan into the repository.
2. Make the smallest architectural decisions needed to produce the first vertical slice.
3. Begin implementing immediately.
4. Keep the repository buildable.
5. Run tests after meaningful milestones.
6. Do not stop at documentation or scaffolding.
7. Produce a working .app against the example project.
8. Record important tradeoffs in docs/architecture.md.
9. Prefer a narrower working implementation over an elaborate unfinished architecture.
10. Do not ask the user to decide low-level implementation details unless the decision fundamentally changes the product philosophy.

When there is ambiguity, choose the solution that best supports:

* local transparency
* project-local storage
* minimal hidden system state
* compatibility with AI coding agents
* simplicity for nontechnical users
* a lightweight generated .app
* reliable hot development
* future extensibility without premature platform complexity

The central idea to preserve is:

The user owns an app. Enmanner manages the invisible development mechanics on their behalf.

And:

The repository is the source of truth. The .app is the front door.
