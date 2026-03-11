# Logos Workspace

Nix-based multi-repo workspace for the Logos modular application platform. ~41 repos as git submodules under `repos/`. C++17/Qt 6, CMake, Nix flakes.

## The `ws` CLI

The workspace has a custom CLI (`scripts/ws`) that manages all repos. Use it instead of raw nix commands.

```bash
# Building and running
ws build <repo> [--auto-local]       # Build (auto-override dirty deps)
ws build <repo> --local dep1 dep2    # Build with explicit local overrides
ws run <repo> [--auto-local]         # Build and run
ws test <repo>                       # Run repo's nix checks
ws test --all [--type cpp|rust|nim]  # Test all repos

# Watching (auto-rebuild/test on save)
ws watch test <repo>                 # Re-test on file change
ws watch build <repo> --auto-local   # Re-build on file change

# Cross-repo operations
ws status                            # Git status across all repos
ws dirty                             # Dirty repos + downstream impact
ws graph <repo>                      # Show deps/dependents
ws foreach <cmd>                     # Run command in every repo
ws foreach 'git add . && git commit -m "msg" || true'

# Other
ws develop [repo]                    # Enter dev shell (zsh+tmux+tools)
ws update [repo]                     # Update flake inputs
ws loc [repo] [--all] [--no-nix]    # Lines of code
ws worktree add <name> [-b branch]  # Isolated multi-repo feature branch
ws list                              # Show all repos
ws sync-graph                        # Regenerate dep-graph.nix
```

Use `ws <command> --help` for detailed usage.

## Searching code

All source lives under `repos/`. Use Grep/Glob tools with path `repos/`:

```bash
rg "pattern" repos/                  # Search code across all repos
rg "pattern" repos/logos-cpp-sdk/    # Search one repo
fd "pattern" repos/                  # Find files by name
```

## How overrides work

`--auto-local` detects repos with uncommitted changes and passes `--override-input` flags to nix. Because the workspace flake uses `follows` declarations, overriding one input propagates to all downstream consumers automatically. This is the key feature — edit a library, build a downstream app, and your changes flow through the entire dependency chain.

## Architecture

```
logos-app / logoscore (runtime)
    |
    v
modules (Qt plugins, process-isolated, communicate via Qt Remote Objects)
    |
    v
logos-liblogos (core runtime: logoscore CLI, logos_host, liblogos_core)
    |
    v
logos-cpp-sdk (SDK: LogosAPI, LogosResult, code generator, IPC layer)
    |
    v
nixpkgs (Qt 6, system libs — pinned via logos-cpp-sdk)
```

## Key repos

| Repo | Role |
|------|------|
| logos-cpp-sdk | SDK root. Pins nixpkgs/Qt. Code generator, LogosAPI, IPC |
| logos-liblogos | Core runtime: `logoscore`, `logos_host`, `liblogos_core` |
| logos-module | Plugin introspection library + `lm` CLI |
| logos-module-builder | Scaffolding + build system (module.yaml -> CMake) |
| logos-app-poc | Desktop app shell with sidebar, tabs, plugin management |
| logos-package | LGX package format + `lgx` CLI |

## Building and testing a repo

```bash
# Build
ws build logos-liblogos
ws build logos-app-poc --auto-local    # with local overrides

# Test
ws test logos-module                   # single repo
ws test --all --type cpp               # all C++ repos

# Enter a repo's own dev shell (has that repo's build tools)
ws develop logos-cpp-sdk
```

## Module development

Modules are Qt plugins built with CMake+Nix. Each module has:
- `module.yaml` — declarative config (name, version, deps, cmake settings)
- `flake.nix` — nix build (~15 lines, uses logos-module-builder)
- `src/` — C++ sources (Q_INVOKABLE methods = module API)

Scaffold a new module:
```bash
nix flake init -t github:logos-co/logos-module-builder
```

## Important documentation

- **Developer guide** (comprehensive, 1100 lines): `repos/logos-tutorial/logos-developer-guide.md`
- **SDK README** (code generator, LogosResult API): `repos/logos-cpp-sdk/README.md`
- **Runtime README** (logoscore CLI, building): `repos/logos-liblogos/README.md`
- **Module builder README** (scaffolding, module.yaml): `repos/logos-module-builder/README.md`

Read the developer guide first when working on module code. It covers the full lifecycle: creating, building, testing, packaging, inter-module communication.

## Dependency chain

```
nixpkgs (pinned by logos-cpp-sdk)
  -> logos-cpp-sdk
    -> logos-module
    -> logos-liblogos
      -> logos-capability-module, logos-package, logos-module-builder
      -> logos-accounts-module, logos-chat-module, logos-waku-module, ...
      -> logos-app-poc (aggregates many modules)
```

Changing `logos-cpp-sdk` affects everything. Changing a leaf module (e.g., `logos-chat-module`) affects only `logos-app-poc`. Use `ws graph <repo>` or `ws dirty` to see impact.

## Gotchas

- All builds go through nix. Don't try raw `cmake` without `nix develop` or `ws develop` first.
- `--auto-local` uses whatever is on disk, including broken WIP. Use `--local` for precision.
- After adding tests to a repo's flake.nix, run `ws sync-graph` so `ws test` discovers them.
- The workspace `nixpkgs` follows `logos-cpp-sdk/nixpkgs`. Never pin a separate nixpkgs.
- Flake inputs must be tracked by git. Run `git add <file>` before nix can see new files.
- Qt version is fixed by logos-cpp-sdk. All repos must follow it to avoid version conflicts.

## Nix patterns

```bash
# Build any repo's default package
nix build .#logos-cpp-sdk

# Enter a repo's dev shell directly
nix develop path:./repos/logos-cpp-sdk

# Manual override (ws does this for you)
nix build .#logos-app-poc --override-input logos-cpp-sdk path:./repos/logos-cpp-sdk
```

## CLI tools (available after building relevant repos)

- `lm` — module inspector: `lm metadata <plugin>`, `lm methods <plugin>`
- `logoscore` — headless runtime: `logoscore -m <dir> --load-modules <name>`
- `lgx` — package tool: `lgx create`, `lgx add-variant`, `lgx list`, `lgx verify`
- `lgpm` — package manager: `lgpm install`, `lgpm search`, `lgpm list`
- `logos-cpp-generator` — SDK code generator from plugin metadata
