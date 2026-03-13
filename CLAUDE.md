# Logos Workspace

Nix-based multi-repo workspace for the Logos modular application platform. ~43 repos as git submodules under `repos/`. C++17/Qt 6, CMake, Nix flakes.

## Setup

Run this first to add workspace tools to PATH:
```bash
export PATH="/workspace/scripts:$PATH"
```

## The `ws` CLI

The workspace has a custom CLI (`scripts/ws`) that manages all repos. Use it instead of raw nix commands.

```bash
# Building, running, and testing (all support --auto-local / --local)
ws build <repo> [--auto-local]       # Build (auto-override dirty deps)
ws build <repo> --local dep1 dep2    # Build with explicit local overrides
ws run <repo> [--auto-local]         # Build and run
ws test <repo> [--auto-local]        # Run repo's nix checks
ws test <repo> --local dep1 dep2     # Test with explicit local overrides
ws test --all [--type cpp|rust|nim]  # Test all repos
ws test --all --workspace            # Test using all local workspace deps
ws develop [repo] [--auto-local]     # Enter dev shell (zsh+tmux+tools)

# Repo groups (operate on named sets of repos)
ws groups                            # List all groups and members
ws build --group core                # Build all repos in the "core" group
ws test --group chat --auto-local    # Test all repos in the "chat" group

# Watching (auto-rebuild/test on save, flags pass through)
ws watch test <repo> [--auto-local]  # Re-test on file change
ws watch build <repo> --auto-local   # Re-build on file change

# Cross-repo operations
ws status                            # Git status across all repos
ws dirty                             # Dirty repos + downstream impact
ws graph <repo>                      # Show deps/dependents
ws foreach <cmd>                     # Run command in every repo
ws foreach 'git add . && git commit -m "msg" || true'

# Other
ws update [repo]                     # Update flake inputs
ws loc [repo] [--all] [--no-nix]    # Lines of code
ws worktree add <name> [-b branch]  # Isolated multi-repo feature branch
ws list                              # Show all repos
ws sync-graph                        # Regenerate dep-graph.nix
```

All commands accept `--quiet` / `-q` to suppress informational output and colors (useful for CI/scripting).

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

## Repo groups

Named sets of repos for batch operations. Groups can reference other groups (resolved recursively). Defined in the `REPO_GROUPS` array in `scripts/ws`.

```bash
# Built-in groups:
#   core            — logos-cpp-sdk, logos-module, logos-liblogos, logos-module-builder,
#                     logos-capability-module, logos-package-manager-module, logos-test-modules
#   chat            — core + logos-chat-module, logos-chatsdk-module, logos-waku-module, logos-irc-module
#   package-manager — logos-package, logos-package-manager-module, logos-package-manager-ui, nix-bundle-lgx
#   app             — core + logos-app-poc, logos-package-manager-ui

# List groups and their members
ws groups

# Use --group/-g with most commands that accept repos
ws build --group core
ws test --group chat --auto-local
ws graph --group core
ws loc --group app
ws watch test --group core --auto-local
```

The `--group` flag accepts multiple group names: `ws build --group core chat`.

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
| nix-bundle-dir | Bundles Nix derivations into portable self-contained dirs |
| nix-bundle-lgx | Bundles Nix derivations into distributable `.lgx` packages |

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
      -> logos-capability-module, logos-package, logos-module-builder, nix-bundle-dir
      -> nix-bundle-lgx (uses logos-package + nix-bundle-dir)
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

## CLI tools (auto-build, auto-rebuild)

Available directly or as `ws` subcommands (e.g. `lgx` or `ws lgx`).
Auto-build on first use, auto-rebuild when source files change. Only builds the specific binary, not the full repo.

### `logoscore` — headless module runtime (logos-liblogos)

Loads modules and optionally calls their methods. Essential for testing modules without the full GUI app.

```bash
logoscore [options]
  -m, --modules-dir <path>         Directory to scan for module plugins (repeatable)
  -l, --load-modules <mod1,mod2>   Comma-separated modules to load (auto-resolves deps)
  -c, --call <module.method(args)> Call a method after loading (repeatable, sequential)
  -h, --help                       Show help
  --version                        Show version
```

Method call syntax for `-c`: `module_name.method(arg1, arg2)`
- Type auto-detection: `true`/`false` → bool, `42` → int, `3.14` → double, else → string
- `@filename` loads file content as the argument (e.g. `@config.json`)
- 30-second timeout per call; exit code 1 on failure

```bash
# Load a module (auto-resolves transitive dependencies)
logoscore -m ./modules --load-modules my_module

# Load and call a method
logoscore -m ./modules -l my_module -c "my_module.doSomething(hello)"

# Sequential calls with file parameter
logoscore -m ./modules -l storage_module \
  -c "storage_module.init(@config.json)" \
  -c "storage_module.start()"

# Multiple modules (deps resolved automatically)
logoscore -m ./modules -l waku_module,chat,my_module
```

### `lm` — module inspector (logos-module)

Introspects compiled Qt plugin files to show metadata and method signatures.

```bash
lm [command] <plugin-path> [options]

Commands:
  (none)       Show both metadata and methods
  metadata     Show plugin metadata only
  methods      Show exposed Q_INVOKABLE methods only

Options:
  --json       Output structured JSON (works with all commands)
  --debug      Show Qt debug output during plugin loading
  -h, --help   Show help
  -v, --version
```

```bash
# Inspect a built module
lm ./result/lib/my_module_plugin.so
lm metadata ./result/lib/my_module_plugin.so
lm methods ./result/lib/my_module_plugin.so --json

# JSON metadata output includes: name, version, description, author, type, dependencies
# JSON methods output includes: name, signature, returnType, isInvokable, parameters[]
```

### `lgx` — LGX package tool (logos-package)

Creates and manages `.lgx` packages (gzip tar archives with platform-specific variants).

```bash
lgx <command> [options]

Commands:
  create <name>                     Create empty .lgx package
  add <pkg> -v <variant> -f <path>  Add files to a variant (replaces if exists)
    --variant, -v <name>              Variant name (e.g. linux-x86_64, darwin-arm64)
    --files, -f <path>                File or directory to add
    --main, -m <relpath>              Main entry point (required if --files is a directory)
    --yes, -y                         Skip confirmation prompts
  remove <pkg> -v <variant>         Remove a variant
  extract <pkg> [-v <variant>] [-o <dir>]  Extract variant(s)
  verify <pkg>                      Validate against LGX spec
  sign <pkg>                        (not yet implemented)
  publish <pkg>                     (not yet implemented)
```

```bash
# Create and populate a package
lgx create my_module
lgx add my_module.lgx -v linux-x86_64 -f ./result/lib/my_module_plugin.so
lgx add my_module.lgx -v darwin-arm64 -f ./result/lib/my_module_plugin.dylib

# Add a directory variant with main entry point
lgx add my_module.lgx -v web -f ./dist --main index.js -y

# Inspect and verify
lgx verify my_module.lgx
lgx extract my_module.lgx -v linux-x86_64 -o ./extracted
```

### `lgpm` — package manager (logos-package-manager-module)

Installs, searches, and manages module packages. Fetches from GitHub releases with automatic dependency resolution.

```bash
lgpm [global-options] <command> [options]

Global options:
  --modules-dir <path>       Target directory for core modules
  --ui-plugins-dir <path>    Target directory for UI plugins
  --release <tag>            GitHub release tag (default: latest)
  --json                     Output JSON format
  -h, --help

Commands:
  search <query>             Search packages by name/description
  list [--category <cat>] [--installed]  List packages
  info <package>             Show package details
  categories                 List available categories
  install <pkg> [pkgs...]    Install packages (resolves deps automatically)
    --file <path>              Install from local .lgx file instead
```

```bash
# Search and browse
lgpm search waku
lgpm list --installed
lgpm list --category networking
lgpm info my_module

# Install from registry (with automatic dep resolution)
lgpm --modules-dir ./modules install my_module

# Install from local .lgx file
lgpm --modules-dir ./modules install --file ./my_module.lgx

# Install specific release
lgpm --modules-dir ./modules --release v2.0.0 install my_module
```

## Creating a new module

Scaffold, build, test, package — the full lifecycle:

```bash
# 1. Scaffold
mkdir logos-my-module && cd logos-my-module
nix flake init -t github:logos-co/logos-module-builder
# Edit module.yaml (name, version, deps) and src/ files
# For modules wrapping external C/C++ libs, use the #with-external-lib template instead

# 2. Build
git init && git add -A   # nix needs files tracked by git
nix build                # outputs: result/lib/<name>_plugin.so, result/include/

# 3. Inspect
lm ./result/lib/my_module_plugin.so              # metadata + methods
lm methods ./result/lib/my_module_plugin.so --json  # method signatures as JSON

# 4. Test with logoscore
logoscore -m ./result/lib -l my_module -c "my_module.someMethod(arg)"

# 5. Package
lgx create my_module
lgx add my_module.lgx -v linux-x86_64 -f ./result/lib/my_module_plugin.so
lgx verify my_module.lgx

# 6. Install locally
lgpm --modules-dir ./test-modules install --file ./my_module.lgx

# 7. Run with other modules
logoscore -m ./test-modules -l my_module -c "my_module.someMethod(test)"
```

Key files in a module:
- `module.yaml` — name, version, type, category, dependencies, nix_packages, external_libraries, cmake settings
- `flake.nix` — ~15 lines, calls `logos-module-builder.lib.mkLogosModule`
- `src/<name>_interface.h` — pure virtual interface (inherits `PluginInterface`)
- `src/<name>_plugin.h` — `Q_OBJECT` + `Q_INVOKABLE` methods = public API
- `src/<name>_plugin.cpp` — implementation
- `CMakeLists.txt` — uses `logos_module()` macro from LogosModule.cmake

Every `Q_INVOKABLE` method is automatically discoverable by `lm`, callable by `logoscore -c`, and accessible from other modules via `LogosAPI`.

## Inter-module communication

Modules receive a `LogosAPI*` pointer via `initLogos()`. Use it to call other modules:

```cpp
// Raw call
LogosAPIClient* client = logosAPI->getClient("other_module");
QVariant result = client->invokeRemoteMethod("other_module", "method", arg1, arg2);

// Or use generated type-safe wrappers (from logos-cpp-generator):
LogosModules* logos = new LogosModules(logosAPI);
QString result = logos->other_module.doSomething("hello");
```

Return structured results with `LogosResult`:
```cpp
Q_INVOKABLE LogosResult fetchData(const QString& id) {
    if (id.isEmpty()) return {false, QVariant(), "ID cannot be empty"};
    QVariantMap data; data["id"] = id; data["count"] = 42;
    return {true, data};
}
```
