# Manifest

`enmanner/enmanner.json` is project-owned, versioned configuration.
`.enmanner/enmanner.schema.json` provides editor and agent validation. The
containing directory is always spelled exactly `enmanner/`.

Manifest version 3 models the application as a graph of named runtime
components. A concise inline form covers the common single-process application
without exposing graph configuration:

```json
{
  "$schema": "../.enmanner/enmanner.schema.json",
  "version": 3,
  "name": "Household Finances",
  "identifier": "local.enmanner.household-finances",
  "application": {
    "command": [
      "npm",
      "run",
      "dev",
      "--",
      "--host",
      "127.0.0.1",
      "--port",
      "${self.endpoints.http.port}",
      "--strictPort"
    ],
    "workingDirectory": ".",
    "environment": {
      "PORT": "${self.endpoints.http.port}"
    },
    "preferredPort": 43120,
    "readiness": {
      "path": "/",
      "timeoutSeconds": 30
    }
  },
  "window": {
    "width": 1200,
    "height": 800,
    "resizable": true
  }
}
```

The loader lowers this shorthand into the same component graph used by a
multi-process application. There is one lifecycle implementation.

## Component graphs

Use `components` when the application owns multiple processes, startup tasks,
or observed external prerequisites:

The integration root is a runtime boundary, not necessarily a repository. For
example, sibling source repositories can form one application:

```text
StudioWorkspace/
├── Frontend/.git/
├── Backend/.git/
├── Shared/.git/
├── enmanner/enmanner.json
└── .enmanner/
```

In that layout, the frontend can be the browser-facing `application`, the
backend can be a managed `service`, and a separately administered PostgreSQL
instance can be a `prerequisite`. The frontend depends on the backend and
receives its allocated URL through an endpoint reference. Because the workspace
root itself is unversioned, the integration should either give the root
repository ownership or record its unversioned durability with
`--allow-unversioned`. When this common workspace is the high-confidence root
of a user-requested integration, that flag is an agent acknowledgement rather
than a separate product question.

```json
{
  "version": 3,
  "name": "Studio",
  "identifier": "local.enmanner.studio",
  "components": {
    "postgres": {
      "kind": "prerequisite",
      "check": {
        "type": "command",
        "command": [
          "docker",
          "inspect",
          "studio_postgres",
          "--format",
          "{{.State.Health.Status}}"
        ],
        "success": {
          "stdoutEquals": "healthy"
        },
        "timeoutSeconds": 5
      },
      "failureMessage": "Start the local PostgreSQL container first."
    },
    "redis": {
      "kind": "prerequisite",
      "endpoints": {
        "tcp": {
          "protocol": "tcp",
          "port": {
            "fixed": 6379
          }
        }
      },
      "check": {
        "type": "tcp",
        "endpoint": "tcp",
        "timeoutSeconds": 5
      },
      "failureMessage": "Start the local Redis message bus first."
    },
    "migrate": {
      "kind": "task",
      "dependsOn": ["postgres"],
      "command": ["./bin/studio", "db:migrate"],
      "workingDirectory": "Backend"
    },
    "prepare-api": {
      "kind": "task",
      "dependsOn": ["migrate"],
      "command": ["./bin/studio", "prepare-and-serve"],
      "workingDirectory": "Backend",
      "environment": {
        "PORT": "${self.endpoints.http.port}"
      },
      "endpoints": {
        "http": {
          "protocol": "http",
          "port": {}
        }
      },
      "completion": {
        "type": "http",
        "endpoint": "http",
        "path": "/api/v1/health",
        "timeoutSeconds": 1200
      }
    },
    "api": {
      "kind": "service",
      "dependsOn": ["prepare-api", "redis"],
      "command": ["./bin/studio", "serve"],
      "workingDirectory": "Backend",
      "environment": {
        "PORT": "${self.endpoints.http.port}",
        "REDIS_URL": "${components.redis.endpoints.tcp.url}"
      },
      "endpoints": {
        "http": {
          "protocol": "http",
          "port": {}
        }
      },
      "readiness": {
        "type": "http",
        "endpoint": "http",
        "path": "/api/v1/health",
        "timeoutSeconds": 60
      }
    },
    "worker": {
      "kind": "service",
      "dependsOn": ["api", "redis"],
      "command": ["./bin/studio", "worker"],
      "workingDirectory": "Backend",
      "environment": {
        "API_URL": "${components.api.endpoints.http.url}",
        "REDIS_URL": "${components.redis.endpoints.tcp.url}"
      },
      "readiness": {
        "type": "process",
        "minimumUptimeSeconds": 3,
        "timeoutSeconds": 30
      }
    },
    "frontend": {
      "kind": "service",
      "dependsOn": ["api", "worker"],
      "command": [
        "npm",
        "run",
        "dev",
        "--",
        "--host",
        "127.0.0.1",
        "--port",
        "${self.endpoints.http.port}",
        "--strictPort"
      ],
      "workingDirectory": "Frontend",
      "environment": {
        "API_URL": "${components.api.endpoints.http.url}"
      },
      "endpoints": {
        "http": {
          "protocol": "http",
          "port": {
            "preferred": 45123
          }
        }
      },
      "readiness": {
        "type": "http",
        "endpoint": "http",
        "path": "/",
        "timeoutSeconds": 120
      }
    }
  },
  "application": {
    "component": "frontend",
    "endpoint": "http",
    "path": "/"
  },
  "window": {
    "width": 1440,
    "height": 900,
    "resizable": true
  }
}
```

Component names use lowercase letters, digits, and hyphens. `dependsOn`
provides startup ordering:

- A service dependency must pass its required readiness probe.
- A task dependency must exit successfully or pass its configured completion
  probe.
- A prerequisite dependency must pass its check.

Dependencies are explicit. A component that references another component's
endpoint must also name it in `dependsOn`. Unknown components, unknown
endpoints, hidden reference edges, and cycles fail static validation.

Independent branches may be represented in the same graph. The initial version
starts ready components sequentially in deterministic topological order;
unrelated branches are not started concurrently. On Quit, managed
services stop in reverse topological order. Each service owns a separate
process group. If a service later exits, Enmanner restarts that component and
its transitive dependants while leaving unrelated branches and healthy upstream
dependencies running.

## Component kinds

`service` is the default. It runs one foreground executable-plus-argument array
for the application lifetime and requires `readiness`. HTTP and TCP readiness
describe network services; process readiness gives workers an explicit,
bounded minimum-uptime gate.

`task` runs once per Enmanner launch after its dependencies are satisfied. It
must exit with status zero before dependents start. Database migrations are a
typical task. A task that must temporarily run a server may instead declare
endpoints and a `completion` probe. Enmanner waits for that probe, terminates
the task's process group, and then starts dependents. This covers first-run
preparation without a project-authored supervisor script. Probe timeouts may be
as long as 86400 seconds. Normal automation uses `validate --runtime --json`
for a bounded final result; during active diagnosis, `--json-lines` streams the
task's labelled stdout and stderr as progress.
After a task succeeds, recovery retains that result for the launcher session;
restarting a failed service and its dependants does not rerun the task.

`prerequisite` observes something Enmanner does not own. It has `check` rather
than `command`; Enmanner never starts, adopts, restarts, or stops it. Docker
Desktop, shared databases, and already-running infrastructure belong here.
Classify by the intended lifecycle, not by repository boundaries: an HTTP API
that opening the app should start is a `service` even when it lives in a sibling
repository. If a required application service is declared as a prerequisite,
the user must start it manually; confirm that product decision explicitly.

Checks are startup gates. Enmanner treats an owned service process exiting as
an ongoing failure signal, but it does not infer continuous health monitoring
from readiness probes or prerequisite checks.

## Endpoints and references

An endpoint has a `protocol` (`http`, `https`, or `tcp`), a loopback `host`
(default `127.0.0.1`), and a port:

```json
{
  "protocol": "http",
  "host": "127.0.0.1",
  "port": {
    "preferred": 45123
  }
}
```

- An empty `port` object requests an allocated loopback port.
- `preferred` requests a stable port with allocated fallback.
- `fixed` requires that exact port.
- `fixed` and `preferred` are mutually exclusive.

Endpoints on a `prerequisite` must use `fixed`, because Enmanner observes that
listener rather than choosing the port or starting its owner.
Prerequisite ports are reported as observed, not owned. Runtime shutdown
validation requires only service and completion-task ports to be released; an
external database remaining available is correct.

Endpoint values are frozen for one launcher session. Enmanner constructs URLs,
including IPv6 formatting, and supports only these exact references:

- `${self.endpoints.http.host}`
- `${self.endpoints.http.port}`
- `${self.endpoints.http.url}`
- `${components.api.endpoints.http.host}`
- `${components.api.endpoints.http.port}`
- `${components.api.endpoints.http.url}`
- `${project.directory}`

There is no expression language or shell expansion. Unknown references fail.

## Probes

HTTP and TCP probes reference an endpoint on their component. HTTP probes may
also declare `path`, `acceptableStatusCodes`, `contentTypeContains`, and
`bodyContains`.

A command probe runs an executable-plus-argument array directly with a strict
timeout. Exit status zero succeeds unless `success.stdoutEquals` or
`success.stdoutContains` adds a bounded output assertion. Command probes do not
invoke a shell.

A process probe succeeds after the component remains alive for
`minimumUptimeSeconds`, which defaults to 2. It is intended for workers with no
meaningful network endpoint.

`readiness` is the startup gate for managed services, `completion` is the
success gate for a long-running startup task, and `check` is the corresponding
gate for prerequisites. Probe timeouts default to 30 seconds and may be set up
to 86400 seconds. A process exiting remains the default ongoing failure signal;
readiness is not silently converted into continuous health monitoring.
Runtime validation additionally observes the ready graph for five seconds by
default so a component that fails shortly after its gate is not accepted.
The service referenced by `application` must use HTTP readiness against that
same endpoint, because passing readiness authorizes Enmanner to open the page.

## Commands and paths

Commands are arrays. Enmanner executes the first item directly and never invokes
a shell. Relative executable paths resolve from the component's
`workingDirectory`. Bare names use Enmanner's GUI-safe `PATH`; absolute
executables are supported.

When a project depends on an executable installed outside the standard macOS,
Homebrew, or `/usr/local` locations, declare its directory once at the manifest
root:

```json
{
  "executableSearchPaths": ["~/.nix-profile/bin"]
}
```

Entries must be absolute or home-relative (`~/…`) directories. Enmanner
prepends them to the GUI-safe `PATH` before resolving command executables and
passes that same `PATH` to child processes. This is an explicit per-project
compatibility setting, not a global PATH change.

Configured working directories and relative executables must remain inside the
project. Every managed service must remain in the foreground, bind declared
network listeners to loopback, and keep descendants in its owned process group.

## App icons

Projects shared by Macs with different Apple toolchains can configure both icon
formats:

```json
{
  "icon": {
    "modern": "enmanner/icon/AppIcon.icon",
    "legacy": "enmanner/icon/AppIcon.icns"
  }
}
```

When Xcode's `actool` is available, `build-app` selects and compiles `modern`.
On a Command Line Tools-only Mac, it selects `legacy`. Both paths are
project-relative, must stay under the project-owned `enmanner/` directory, and
must exist. A single string remains supported for existing manifests:

```json
{
  "icon": "enmanner/icon/AppIcon.icon"
}
```

A modern-only configuration still requires full Xcode. A legacy-only
configuration retains the existing `--allow-legacy-icon` safeguard on a Mac
where modern tooling is available.

## User configuration

Optional `userConfiguration` exposes a curated set of dotenv values in the
native Settings window:

```json
{
  "userConfiguration": {
    "file": ".env",
    "template": ".env.example",
    "fields": [
      {
        "key": "IMPORT_DIRECTORY",
        "label": "Import Directory",
        "type": "directory",
        "required": true
      },
      {
        "key": "TEAM_API_KEY",
        "label": "Team API Key",
        "type": "secret"
      }
    ]
  }
}
```

`file` defaults to `.env` and must be a Git-ignored, project-owned file outside
`.enmanner/`. An optional template supplies initial content. Enmanner never
infers fields from it.

Field types are `string`, `secret`, `boolean`, `file`, and `directory`. Saving
preserves comments, ordering, and undeclared entries, then restarts the runtime.
Secret controls affect native presentation only; values remain ordinary dotenv
values and never enter the manifest, app bundle, logs, or diagnostics.

## Application presentation

The referenced application endpoint must use HTTP or HTTPS. Enmanner appends
the configured application path, waits for the component's startup readiness,
then opens it in the default browser. The launcher remains windowless while
healthy and keeps the runtime owned by the Dock application. Dimensions and
resizability affect native status windows and require an app rebuild.

## Icon

`icon` remains a project-relative path inside `enmanner/`. Prefer an Icon
Composer `.icon` package when `actool` is available. A legacy `.icns` remains an
explicit compatibility fallback as described by the icon integration
instructions.
