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
there is no framework override area. Project supervisors, icons, data, scripts,
`enmanner.json`, and the application source remain outside `.enmanner/` and
project-owned. Installed distributions include native `Sources` but omit the
framework's tests and installer. The installer
offers a non-mutating JSON plan and stops with `configurationRequired` rather
than manufacturing an unverified startup command. It still installs the
framework and writes a deliberately inactive `enmanner.json.example` preserving
presentation choices and candidate evidence. Inferred single-app integrations
receive a deterministic preferred port so browser-origin state remains stable
when that port is available.

Enmanner does not build a placeholder app. Agents validate server lifecycle
before spending time on artwork, then create and preview a distinctive icon
before the first `.app` is produced. `preview-icon` renders every supported
Icon Composer appearance for agent-visible inspection.

Agents should perform conservative Git work in user-facing terms: make a
checkpoint before risky migrations, save a working milestone after verification,
and never overwrite uncommitted work. Generated apps, build directories,
dependencies, secrets, live databases, uploads, and caches stay out of Git;
source, lockfiles, the manifest, migrations, and `.enmanner/` stay in it.

Runtime validation is deliberately stronger than static validation and is not
assumed to be side-effect-free. Before invoking it, agents inspect stateful
services, persistence mounts, existing ownership, and shutdown commands. After
readiness, the validator proves observable process-group, endpoint, port, and
tracked-descendant shutdown postconditions and reports workspace mutations.
Agents still verify requested startup commands against the current repository
instead of treating remembered target names as authoritative.
