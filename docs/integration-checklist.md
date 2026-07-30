# Integration checklist

Use this checklist to route an Enmanner integration; the installed
`.enmanner/instructions/integration.md` is the sole normative step-by-step
sequence.

1. Confirm that the target has a human-facing local web interface. Ask before
   wrapping a headless API, proxy, worker, daemon, CLI, or infrastructure
   service.
2. Inspect project ownership, Git state, runtime data, and existing services.
3. Run `integration/scripts/install --plan --json /path/to/project`. Review
   `installationState`, `safeRecovery`, file operations, compatibility evidence,
   and `requiredInstructions`.
4. Apply the installation. For `cacheOnly`, the installer removes only known
   disposable build caches. For incomplete or receiptless framework state,
   review and explicitly use `--replace-incomplete`; it relocates the old
   framework before installing.
5. Continue from the installed `.enmanner/instructions/integration.md`. Use
   `./.enmanner/scripts/doctor --next` for a project-specific Markdown summary
   of the remaining work and relevant focused references.

Enmanner reports completion as evidence milestones:

- `configured`
- `lifecycleVerified`
- `developmentNativeVerified`
- `presentationReady`
- `finalNativeVerified`
- `repositoryReady`

Local technical completion and repository readiness are separate. Enmanner
never stages or commits files. Overall `complete` requires both a verified final
application and durable repository ownership, or an explicitly accepted
unversioned workspace.

Use inline `application` configuration for one frontend command. Use component
graphs for multiple project-owned services, startup tasks, or observed
prerequisites. Commands remain executable-plus-argument arrays; managed
listeners bind loopback and use allocated endpoints.
