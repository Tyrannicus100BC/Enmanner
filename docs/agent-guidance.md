# Agent guidance package

Installed Enmanner projects contain a concise `.enmanner/AGENTS.md` entry point linking
to focused instruction files. This avoids mixing compatibility requirements,
recommended application practices, and future architecture.

The package uses:

- **MUST** for launcher compatibility and security boundaries
- **SHOULD** for safe application defaults
- **MAY** for optional capabilities

Native presentation is also agent-owned finishing work. The package tells
agents to inspect existing assets for a suitable app icon and, when none
exists, to use their image-generation capability rather than ship a generic or
missing icon. It distinguishes layered Icon Composer source artwork from modern
bundle packaging: Enmanner compiles a configured `.icon` package into `Assets.car`
and retains `.icns` only as an older-macOS fallback. Source artwork and icon
packages remain tracked project assets.

The root installer preserves existing agent instructions and appends a clearly
delimited reference to Enmanner. Framework-owned files live under `.enmanner/` and
should be replaced only through a deliberate upgrade; `enmanner.json` and the
application source remain project-owned.

Agents should perform conservative Git work in user-facing terms: make a
checkpoint before risky migrations, save a working milestone after verification,
and never overwrite uncommitted work. Generated apps, build directories,
dependencies, secrets, live databases, uploads, and caches stay out of Git;
source, lockfiles, the manifest, migrations, and `.enmanner/` stay in it.

Runtime validation is deliberately stronger than static validation and is not
assumed to be side-effect-free. Before invoking it, agents inspect stateful
services, persistence mounts, existing ownership, and shutdown commands. They
also verify requested startup commands against the current repository instead
of treating remembered target names as authoritative.
