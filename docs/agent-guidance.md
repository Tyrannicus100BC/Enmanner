# Agent guidance package

Installed Enmanner projects contain a concise `.enmanner/AGENTS.md` entry point linking
to focused instruction files. This avoids mixing compatibility requirements,
recommended application practices, and future architecture.

The package uses:

- **MUST** for launcher compatibility and security boundaries
- **SHOULD** for safe application defaults
- **MAY** for optional capabilities

The short `instructions/integration.md` checklist is the authoritative route
through a normal integration. Focused documents remain references for detected
capabilities rather than a reading prerequisite for every project.
Installer plans expose `requiredInstructions` with a reason for each selected
reference so agents can follow this routing mechanically.

Product-scope discovery precedes framework detection. Agents inspect the
proposed target's repository root, parent, and siblings and inventory the full
human-facing workflow before choosing an installation root. This prevents a
convincing frontend or backend development server from being mistaken for a
complete multi-service application. Installer plans report `targetScope`; a
likely repository subproject requires explicit `--allow-subproject`
acknowledgement before files are installed.

Native presentation is also agent-owned finishing work. The package tells
agents that an existing flattened app icon is not necessarily reusable source
artwork. Its hard preflight rejects baked squircles, transparent rounded
corners, borders, shadows, and backing plates; agents reconstruct layered
artwork or use image generation instead of shipping a generic or legacy icon.
When `actool` is available, a configured Icon Composer `.icon` package is a
requirement, not a preference. Enmanner compiles it into `Assets.car`, verifies
the `IconImageStack` and `CFBundleIconName`, and retains `.icns` only as an
older-macOS fallback. Source artwork and icon packages remain tracked project
assets.

The root installer preserves existing agent instructions and appends a clearly
delimited reference to Enmanner. Framework-owned files live under `.enmanner/`
and are replaced only through the checksum-verified repair or upgrade workflow;
there is no framework override area. The `enmanner/` sibling holds the
project-owned manifest, supervisor, icon package, and icon source artwork.
Application source and data remain project-owned outside `.enmanner/`.
Installed distributions include native `Sources` but omit the
framework's tests and installer. The installer reports existing `CLAUDE.md`,
`GEMINI.md`, `.github/copilot-instructions.md`, and `.cursor/rules/` surfaces
without editing them automatically. When one is authoritative, the integrating
agent mirrors the narrowly managed `AGENTS.md` guidance instead of making
Enmanner proliferate tool-specific policy files. The installer
offers a non-mutating JSON plan and stops with `configurationRequired` rather
than manufacturing an unverified startup command. Tested direct Vite, Next.js,
and strongly evidenced Express entry points are the narrow automatic
exceptions; Express remains marked for runtime verification. Other projects
still receive the framework and a deliberately inactive
`enmanner/enmanner.json.example`, preserving presentation choices and candidate
evidence. Inferred single-app integrations receive a deterministic preferred
port so browser-origin state remains stable when that port is available.

Enmanner does not build a placeholder final app. Agents validate server
lifecycle before spending time on artwork and may use the separately named,
badged development bundle to test native lifecycle behavior. They then create
and preview a distinctive icon before producing the finished `.app`.
`preview-icon` renders every supported Icon Composer appearance for
agent-visible inspection and creates a contact sheet plus objective
source-layer measurements. Development evidence is explicitly excluded from
completion.

Agents should perform conservative Git work in user-facing terms: make a
checkpoint before risky migrations, save a working milestone after verification,
and never overwrite uncommitted work. Generated apps, build directories,
dependencies, secrets, live databases, uploads, and caches stay out of Git;
source, lockfiles, the manifest, migrations, and `.enmanner/` stay in it.

Runtime validation is deliberately stronger than static validation and is not
assumed to be side-effect-free. Before invoking it, agents inspect stateful
services, persistence mounts, existing ownership, and shutdown commands. After
readiness, the validator proves observable process-group, endpoint, port, and
tracked-descendant shutdown postconditions and reports Git-status mutations.
Agents still verify requested startup commands against the current repository
instead of treating remembered target names as authoritative.
