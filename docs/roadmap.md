# Roadmap

## After the MVP proves the vertical slice

- Test a wider set of frontend and full-stack development servers.
- Improve escaped-child detection and launch-guard coverage beyond declared
  endpoints and open files.
- Extend the component graph with concurrent startup of independent branches,
  continuous prerequisite and opt-in health observation, component-local
  recovery policies, and richer per-component status.
- Extend the project-declared backup contract with restore conventions only
  after real applications establish safe patterns.
- Add dependency-only preflight and isolated runtime-validation modes for
  stateful services.
- Add machine-readable launcher status and bounded diagnostic log interfaces
  without creating a large hidden workspace.
- Evaluate optional Keychain-backed secret injection only for projects that
  explicitly choose a storage contract other than dotenv.
- Extend icon-source diagnostics beyond the new automated appearance renderer.
- Improve accessibility, menu commands, native update states, and diagnostics.
- Expand conflict-aware upgrades with explicit manifest migrations when a future
  manifest version requires them.

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
