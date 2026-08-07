# Upgrading an installed project

Routine upgrades use the upstream URL already recorded in
`.enmanner/INSTALLATION.json`:

```bash
./.enmanner/scripts/upgrade --check --latest
./.enmanner/scripts/upgrade --latest --verify
```

The first command fetches a temporary checkout and prints a non-mutating
preview. The second applies the checksum-protected update, validates the
configuration, performs bounded runtime verification, rebuilds only when native
sources changed or the app is missing, runs two native launch-and-quit cycles,
and finishes with repository-status evidence. Temporary upstream files are
removed automatically.

For development or an offline source distribution, retain the explicit path:

```bash
./.enmanner/scripts/upgrade --check --from /path/to/Enmanner
./.enmanner/scripts/upgrade --apply --from /path/to/Enmanner --verify
```

Use `--json` for automation. Standard output is exactly one JSON document;
fetching, compilation, and other progress goes to standard error.

The installed `RELEASE_NOTES.json` provides machine-readable release and
migration notes. A routine upgrade does not repeat first-time product-boundary,
persistence, or browser-origin analysis unless its report identifies a relevant
schema or behavior change.
