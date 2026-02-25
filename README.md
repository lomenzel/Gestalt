# Gestalt

Gestalt is a modular framework for building interactive applications in Nix. You describe initial state, actions, and a view, then compile to a target (CLI, TUI, Web). A small runtime executes actions, enforces action params, and renders the view.

## Status

This is an early, experimental project. APIs change and target capabilities are minimal. The core structure, targets, and example apps do work.

## Architecture (Current)

A Gestalt app is defined by a Nix module and transformed into an intermediate representation (IR). Targets consume the IR and produce runnable artifacts.

Flow:

1. Nix module(s): state, actions, view, tests
2. IR (computed by `lib.mkGestaltIR`)
3. Target build (CLI/TUI/Web)

### Module shape

The module interface lives in `src/modules/default.nix` and `src/modules/ir.nix`.

Top-level options:

- `initialState`: attrset, default `{}`
- `actions`: attrset of actions
- `view`: list of functions `(state) -> { elements = [...]; actions = [...] }`
- `stateHooks`: list of functions `(state) -> state`
- `tests.unit`: list of unit tests (run during build)
- `tests.e2e`: list of e2e test specs

Action shape:

- `function`: `{ state, params } -> { state, effect }`
- `paramType`: optional type for params (used by runtimes to prompt users)

View shape:

- `elements`: list of `{ content, annotations? }`
- `actions`: list of `{ content, actionId, annotations?, params? }`

If a view action includes `params`, the runtime dispatches immediately without prompting.

### Effects

Targets provide effects in `target.capabilities.effects`. Available effects (all targets):

- `noop`
- `log`
- `httpRequest`
- `random`
- `invokeAction`

Effects are plain attrsets with `id` and `params`. The web/CLI/TUI runtimes implement them.

### Annotations

Targets also expose UI/action annotations via `target.capabilities.annotations` (e.g. `primary`, `danger`, `heading`, `code`). These currently influence Web styling and can be used by future targets.

## Targets

Implemented targets:

- `cli`: Node.js TTY loop
- `tui`: C++ terminal UI (static lib, uses libcurl for HTTP)
- `web`: Static HTML/CSS/JS with a tiny runtime and a built-in dev server

Each target builds a runnable derivation with a `bin/<app>` entry point.

## Using the flake

The flake exports:

- `overlays.default`: adds `lib` and `gestaltPlatform`
- `packages.<system>`: example apps

### Build and run examples


```bash
nix run github:lomenzel/gestalt#counter.extraTargets.tui
```
> note: gestalt uses a patched version of nix to be able to compile nix functions to c++ or js. So you either need to run it with the patched version `nix run github:lomenzel/nix -- build github:lomenzel/gestalt#counter`, or you need to have the `recursive-nix` experimental feature enabled for gestalt to automatically switch to upstream nix compatibility mode

## Nix fork vs upstream Nix

Gestalt’s IR transformation needs function reification and comparison. That requires a Nix fork providing:

- `builtins.reify`
- `builtins.sameFunction`

If those builtins are missing, `buildGestaltApplication` automatically switches to an upstream compatibility mode (`useUpstreamNix = true`). This mode:

- Requires `src` and `mainFile` (default: `default.nix`) to be passed instead of `modules`
- Builds using a nested flake and the Nix fork
- Requires the `recursive-nix` system feature
- ignores custom targets (only uses their name to find it in gestalt lib.)

## `buildGestaltApplication`

Defined in `src/platform/buildGestaltApplication.nix`.

Arguments:

- `modules`: list of module paths (native mode only)
- `src`: source directory (required in upstream mode)
- `mainFile`: defaults to `default.nix`
- `target`: defaults to `gestaltPlatform.targets.tui`
- `extraTargets`: defaults to all targets (exposed via `passthru.extraTargets`)
- `useUpstreamNix`: override automatic detection

## Examples

Examples live in `examples/`:

- `counter`: basic state/actions + unit/e2e tests
- `http`: demonstrates `httpRequest` effect
- `practiceHelper`: multi-step workflow with `random` + `invokeAction`

## Current limitations

- Effects are minimal and partially implemented (HTTP is GET-only in CLI/TUI).
- E2E tests are still pretty barebones.
- Some Nix features require the custom fork (see above).
