# Gestalt

**Gestalt** is a modular framework for building applications in Nix. It leverages Nix’s functional language features to define state, actions, and targets, making it easy to create composable, reproducible applications.

## Vision

Gestalt aims to make application development in Nix expressive, modular, and cross-platform. By abstracting state, actions, and effects, it enables you to target multiple platforms from a single source of truth.

### Architecture

Gestalt applications are built from modules that define:

- **State**: Your application’s state (can be deeply nested).
- **Actions**: A flat attribute set of actions that can be invoked.

Each module receives the target and application metadata as arguments.


(state, actions, metadata from module evaluation, target provided as argument to modules to be able to reference native effects)

↓

(intermediate representation: adds type annotations, etc.)

↓ ← (target)

(code)


#### State

State is an attribute set containing whatever fields your app needs. Each field should ideally have:

- A type
- A display name
- A function `(state) -> bool` to determine visibility (enables multi-page apps and navigation)
- An initial value

#### Actions

Actions are the only way to modify application state. Each action should have:


- A display name
- A function describing the actual action
    - `{state, params}: {state, effect}` or
    - `{state}: {state, effect}`
- An attribute set defining params types (params are optional)
- a function `state: boolean` defining if its invokable
- a role. (e.g., "default", "navigation" for graphical targets)
- maybe a path to a state object (for graphical targets to position buttons accordingly)

#### Effects

Effects are still under design. The current idea is for actions to return a list of native effects and their parameters, with targets providing native effect implementations and param descriptions. For example, a native effect could be InvokeAction (with an action as a parameter) or HTTPRequest (with method, path, body, and callbacks for success/failure).

This approach would make effects composable, and you could even generate effect factories from Swagger docs for type-checked HTTP APIs.

#### Targets

a target should provide native effects and a function

```
    buildApplication = IntermediateRepresentation:
        resulting derivation. 
```

Potential targets include:

- Web (Frontend only, compiled to HTML that can be used without server (except http native effects of cause)) (e.g., Anguar, Vue ...)
- Android
- QML (KDE)
- GTK (GNOME)
- Iced (Cosmic)
- other platforms, you get the point
- REST API (combined with the other targets this would make Gestalt a full stack web framework, assuming the targets have enough native effects xD)
- KDE Plasma widget
- you name it



## Current Implementation

Work in progress.

### Targets

Two targets are currently implemented:

- **CLI**: Prints the state and accepts action names in a loop. 

- **IR**: Prints the intermediate representation (IR), mainly for debugging

### Effects

Not yet supported.

### State

Only initial values are supported—no annotations, types, or advanced features yet.

### Intermediate Representation

Intermediate Representation
The IR is currently a raw representation of actions and functions, without types or a well-designed structure.

## How to use it

> Note: Gestalt is in early development. Many features are incomplete or experimental.

This Flake provides a `lib.<your-system>` which defines the two basic targets, and a buildGestaltApplication function.

`buildGestaltApplication` takes

- `name`: string,
- `version`: string,
- `modules`: modules to merge with the defaults
- `author`: ` {name: string}`
- `target`: defaults to IR target
- `title`: string

It returnes a derivation built according to target

Function transformation to IR requires Nix functions to be serializable and comparable. This is not possible with upstream Nix. My Nix fork adds two builtins: `builtins.reify` (returns a function’s AST and closure environment) and `builtins.sameFunction` (compares functions by internal pointer).

### Run the example
```bash
nix shell github:lomenzel\#nix -c nix run github:lomenzel/gestalt#examples.counter.cli
```
i also tried to build a wrapper with recursive nix to call my nix fork in the buildPhase of a derivation that can be built using upstream nix, but id does not work yet. See my attempt at `src/lib/upstreamNixCompatibilityWrapper.nix`

