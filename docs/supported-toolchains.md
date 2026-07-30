# Supported toolchain adapters

Enmanner's manifest remains generic, but installer inference is intentionally
limited to combinations whose host, port, foreground lifecycle, and argument
forwarding contracts have been tested.

## Automatically inferred root projects

| Framework | npm | pnpm | Yarn | Bun |
| --- | --- | --- | --- | --- |
| Vite | supported | supported | supported | supported |
| Next.js | supported | supported | supported | supported |

The application must have a root `package.json`, a `dev` script, and a direct
root dependency on the detected framework. Tested script forms are:

- Vite: `vite`, `vite dev`, or `vite serve`
- Next.js: `next dev`, optionally followed by `--turbopack`, `--turbo`, or
  `--webpack`

Custom scripts, wrappers such as `concurrently`, and scripts that already
configure networking receive `configurationRequired`. They may still be valid,
but an agent must review their ownership and lifecycle rather than relying on
automatic inference.

## Package-manager selection

The installer recognizes npm, pnpm, Yarn, and Bun. An explicit
`packageManager` field takes precedence when it is valid and agrees with any
root lockfile. Without that field, one root lockfile selects its corresponding
package manager:

- `package-lock.json` or `npm-shrinkwrap.json` — npm
- `pnpm-lock.yaml` — pnpm
- `yarn.lock` — Yarn
- `bun.lock` or `bun.lockb` — Bun

With no explicit field or lockfile, npm remains the conservative default.
Multiple package-manager lockfiles, an unsupported or malformed
`packageManager` value, or disagreement between the field and lockfile stops
inference and reports `configurationRequired`.

Detection does not install the selected package manager or application
dependencies. They must already be available to the generated GUI application.
Use `./.enmanner/scripts/doctor --json` to inspect the resolved executable and
effective GUI `PATH`.

## Generated networking arguments

Vite adapters pass `--host 127.0.0.1`, the selected `--port`, and
`--strictPort`. Next.js adapters pass `--hostname 127.0.0.1` and the selected
`--port`. npm receives its required `--` argument separator; pnpm, Yarn, and
Bun receive framework arguments directly after the script name.

Projects outside this matrix continue to receive an inactive draft manifest and
structured checks. They are not necessarily incompatible with Enmanner; their
startup contract has not been inferred automatically.

For common Express entry points, the plan reports conservative source evidence
for `process.env.PORT`, loopback host declarations, and a direct
`app.listen(PORT, HOST)` call. When a direct package script launches that same
entry file and all three signals agree, the installer writes an active manifest
with `PORT` and `HOST` wiring and marks it `runtimeVerificationRequired`.
Otherwise it retains an inactive draft populated with whatever networking
evidence is safe to propose. Runtime validation remains the proof.
