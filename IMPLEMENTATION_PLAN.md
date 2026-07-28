# Enmanner MVP implementation plan

This plan favors one complete, testable path: a Vite project with a project-local
Enmanner integration that builds a small native launcher beside its source.

1. Define a versioned manifest and a dependency-free Swift core for decoding,
   validation, project-relative path resolution, port allocation, process
   supervision, environment interpolation, readiness checks, and bounded logs.
2. Build an AppKit + WKWebView launcher with useful starting, running,
   reconnecting, and failed states; embedded and external-browser modes; log
   viewing; retry; reveal-project; and graceful process-tree shutdown.
3. Provide strict project-local scripts to install Enmanner, validate a project,
   compile the launcher, assemble an `.app`, and ad-hoc sign it when available.
4. Package concise agent instructions and human documentation with a clear
   separation between compatibility requirements, recommended practices, and
   future capabilities.
5. Install the integration into a minimal Vite example, build the example app,
   and verify the Swift unit tests plus static and runtime validation.

Deliberate MVP constraints:

- macOS 13 or newer.
- One foreground child server per launcher.
- HTTP readiness on loopback.
- Automatic recovery when a previously-ready server exits, with bounded retry.
- No runtime installer, public networking, sandbox claim, registry, or hidden
  application workspace.
