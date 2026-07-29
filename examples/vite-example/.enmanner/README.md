# Project-local Enmanner

This directory is a vendored Enmanner distribution. Every file inside
`.enmanner/` is framework-owned and should be changed only through Enmanner's
repair or upgrade workflow.

The supported project-facing surface is:

- `../enmanner/enmanner.json` — project-owned configuration;
- `scripts/build-app` — validate and build the native application, with
  optional structured `--json` evidence;
- `scripts/validate` — static or opted-in runtime validation;
- `scripts/doctor` — validation plus installation, manifest-draft, icon,
  generated-app ownership, and managed-file diagnostics;
- `scripts/upgrade` — checksum-verified framework updates;
- `scripts/clean` — remove local Swift build products;
- `scripts/create-icon` — create a layered icon package from project artwork;
- `scripts/preview-icon` — render all supported icon appearances for review;
- `templates/` — files to copy into the visible project before customization.

`framework/` is the native implementation. Do not place project supervisors,
icons, data, scripts, or overrides inside `.enmanner/`; keep Enmanner-specific
project files in the visible `../enmanner/` sibling.
