# Roadmap

## After the MVP proves the vertical slice

- Test a wider set of frontend and full-stack development servers.
- Improve duplicate-launch coordination and escaped-child detection.
- Publish a tested project-level supervisor template for database + backend +
  frontend projects while the manifest still owns one foreground command.
- Design declarative multi-process support with dependency ordering,
  per-service readiness and labelled logs, named or allocated ports,
  required-service failure policy, ownership of pre-existing services, and
  reverse-order shutdown. Treat external prerequisites such as Docker Desktop
  separately from launcher-owned services.
- Add an explicit project-local runtime-data convention and backup helpers.
- Add dependency-only preflight and isolated runtime-validation modes for
  stateful services.
- Add machine-readable doctor, status, launch-report, and bounded diagnostic
  log interfaces without creating a large hidden workspace.
- Define multi-repository workspace placement and explicitly unversioned
  launcher-project conventions.
- Add Keychain-backed secret injection without writing values to the manifest.
- Automate more of the layered Icon Composer artwork workflow.
- Improve accessibility, menu commands, native update states, and diagnostics.
- Define a safe, conflict-aware upgrade flow for framework-owned `.enmanner/` files.
  Include version checks, managed-file provenance, and a supported location for
  project-owned supervisor customizations.

## Later capabilities

- Locally trusted export and polished sharing to another Mac
- Developer ID signing, notarization, and conventional distribution
- Framework adapters only where generic command/readiness configuration is not
  sufficient
- Optional stable-origin proxy if cross-framework recovery testing requires it
- Explicit local-network, remote hosting, and synchronization architectures
- Import/export and backup conventions for user-owned data

These are possibilities, not promises. Enmanner should not become a package manager,
IDE, generic Electron replacement, background daemon, central registry, cloud
platform, or public-tunnel product merely because those capabilities are
adjacent.
