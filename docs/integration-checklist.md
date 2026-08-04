# Integration checklist

Use this checklist to route an Enmanner integration; the installed
`.enmanner/instructions/integration.md` is the sole normative step-by-step
sequence.

1. Before selecting a target, map the complete runtime needed for a useful
   application session. Inspect the current repository root, its parent and
   siblings, startup documentation, frontend proxy/API configuration, and
   service definitions. Inventory every browser-facing process, API, worker,
   startup task, datastore, container, and external dependency.
2. Confirm that the product has a human-facing local web interface. Ask before
   wrapping a headless API, proxy, worker, daemon, CLI, or infrastructure
   service as the application entrypoint. A headless service can still be a
   launcher-owned component when the human-facing application depends on it.
3. Decide the double-click ownership contract before installing. State which
   processes Enmanner will start, which application services the user must
   start manually, and which separately administered infrastructure Enmanner
   will only observe. Default an existing datastore, broker, container, Docker
   Desktop instance, or other persistent infrastructure process to an observed
   prerequisite without asking when it predates the integration, runs
   independently or detached, uses persistent external state, or project docs
   treat startup as environment setup. State that decision non-blockingly.
   Confirm with the user only if a required application service remains manual
   or contrary evidence makes infrastructure ownership ambiguous. Repository
   boundaries do not determine process ownership.
4. Establish the integration root: the common directory containing the
   launcher-owned runtime, not necessarily a source repository or the
   application entrypoint. Do not equate the current directory, nearest Git
   root, or first detected web server with the whole product. When managed
   services live in sibling repositories, their common workspace is normally
   the integration root even when it is unversioned. Select that root
   automatically when it contains the cooperating services and no plausible
   alternative application boundary exists. If the installer reports
   `canProceedWithoutProductDecision: true`, use any required mechanical
   acknowledgement such as `--allow-unversioned`, state the decision, and do
   not ask. Ask only when scope remains materially ambiguous. Keep the Enmanner
   source checkout outside every candidate root;
   on default macOS filesystems, `Enmanner/` conflicts with `enmanner/`.
5. Run `integration/scripts/install --plan --json /path/to/integration-root`. Review
   `installationState`, `safeRecovery`, `recommendedIntegrationRoot`,
   `rootSelectionConfidence`, `configurationDurability`, file operations,
   compatibility evidence, `targetScope`, and `requiredInstructions`. If
   `targetScope.reviewRequired` is
   true, correct the target or explicitly acknowledge an intentional nested app
   with `--allow-subproject`.
6. Select the smallest manifest guide that covers the ownership contract. For
   one frontend process with no manually started application dependency, read
   `docs/manifest-application.md`. For multiple managed services, startup
   tasks, observed prerequisites, or manual application dependencies, read
   `docs/manifest.md`. Do not read both unless the detected shape changes.
7. Apply the installation. For `cacheOnly`, the installer removes only known
   disposable build caches. For incomplete or receiptless framework state,
   review and explicitly use `--replace-incomplete`; it relocates the old
   framework before installing.
8. Continue from the installed `.enmanner/instructions/integration.md`. Use
   `./.enmanner/scripts/doctor --next` for a project-specific Markdown summary
   of the remaining work and relevant focused references. After icon review,
   `./.enmanner/scripts/finish-integration --runtime --json` executes the final
   lifecycle, build, native-test, and doctor gates in order.

During configuration, the integrating agent must inspect origin-scoped browser
storage and state its judgment about adopting an app-specific `.localhost`
browser hostname. It should use the vanity hostname when only disposable UI
state or preferences would be left on the old origin, and preserve the endpoint
host when existing important user state would otherwise become inaccessible.

Enmanner reports completion as evidence milestones:

- `configured`
- `lifecycleVerified`
- `developmentNativeVerified`
- `presentationReady`
- `finalNativeVerified`
- `repositoryReady`

Local technical completion and repository readiness are separate. Enmanner
never stages or commits files. Overall `complete` requires both a verified final
application and durable repository ownership, or a recorded unversioned
workspace.

The final user handoff must name managed services and observed prerequisites,
state that the app runs the local source checkout, distinguish watched/HMR
source from changes that require restart, point to **Window → Runtime Logs**,
describe Quit ownership, and explain same-Mac folder moves versus unsupported
cross-machine app copying.

Use inline `application` configuration only when the entire useful session is
one frontend process with no manually started application dependency. Use
component graphs for multiple project-owned services, startup tasks, or
observed prerequisites. Commands remain executable-plus-argument arrays;
managed listeners bind loopback and use allocated endpoints.
