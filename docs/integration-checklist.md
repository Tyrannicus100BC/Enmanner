# Integration checklist

An Enmanner integration is complete only when project fit, lifecycle behavior,
final native packaging, and visual presentation all pass. A development-only
bundle may be used to prove native lifecycle behavior before icon work, but it
is provisional evidence and can never satisfy completion.

1. Confirm the project has a human-facing local web interface. Stop and ask the
   user before wrapping a headless API, proxy, worker, daemon, CLI, or
   infrastructure service.
2. Inspect Git state, project ownership, runtime data, and existing services.
   For stateful projects, confirm that another terminal-started copy is not
   already using the same data.
3. Run `integration/scripts/install --plan --json`.
4. Install the framework. If the result is `configurationRequired`, review
   `enmanner/enmanner.json.example`, resolve every reported compatibility check, and
   promote a verified configuration to `enmanner/enmanner.json`.
5. Verify the command is an argument array, stays in the foreground, honors
   `ENMANNER_PORT`, and binds to loopback. In browser mode the readiness URL is
   also opened for the user, so it must be a meaningful human-facing page
   rather than a raw health response.
6. Configure a preferred port in browser mode. Inferred manifests already have
   a deterministic choice with fallback.
7. If people must configure machine-local values, add `userConfiguration`.
   Expose only values they should edit or verify, choose the correct control
   type, and mark only genuinely startup-blocking values as required. Use
   consistent human-facing Title Case regardless of dotenv key casing, preserve
   canonical brands and acronyms, and treat optional descriptions as compact
   subtitles: add information the label does not, prefer 45 characters or
   fewer, never exceed 60, and omit the subtitle when it would merely restate
   the label.
8. Run static validation. After reviewing state ownership, opt into runtime
   validation and confirm readiness, shutdown, process-group cleanup, endpoint
   disappearance, port release, and Git-status mutations.
9. When launcher behavior needs proof before icon work, run
   `build-app --development`, then `test-app --development`. The resulting
   `Name Development.app` has a separate bundle identifier, a conspicuous DEV
   icon, and separate doctor evidence. Do not present or report it as the
   finished application.
10. Inspect existing brand assets. Create layered source artwork under
   `enmanner/icon/` when necessary, package a modern `.icon` there, add its
   project-relative path to `enmanner/enmanner.json`, then run `preview-icon`.
   Open the generated contact sheet and confirm that every Default, Dark,
   Clear, and Tinted rendition is balanced and uncropped. Review structured
   source-layer measurements as warnings, not substitutes for visual judgment.
11. Run `build-app`. Verify the compiled icon, ownership marker, code signature,
   and Finder/Dock appearance. Run `test-app` to verify native launch,
   readiness, normal app quit, process cleanup, and port release.
12. Report tracked source and framework files separately from ignored build
   products. Do not call the integration complete before step 11. Development
   build or test receipts do not count as final-build evidence.

For one frontend command, configure it directly. For several project-owned
processes, copy and adapt the project supervisor template. Treat Docker Desktop
and already-running shared services as prerequisites rather than adopted
children.
