---
name: logos-module-development
description: Activate when creating, building, testing, or modifying Logos modules — C++ Qt plugins, module.yaml config, CMake builds, LogosAPI usage, inter-module communication, code generation, packaging (LGX), or working with logos-cpp-sdk, logos-liblogos, logos-module, logos-module-builder repos.
---

# Logos Module Development

Read the full developer guide before making module changes:

```
repos/logos-tutorial/logos-developer-guide.md
```

This 1100-line guide covers the complete lifecycle. Key sections below.

## Architecture

Modules are Qt 6 plugins (C++17) loaded by `logoscore` (headless) or `logos-app` (GUI). Each module runs in its own host process (`logos_host`), communicating via Qt Remote Objects IPC.

```
logos-app / logoscore  ->  logos_host (per module)  ->  module plugin (.so/.dylib)
                                |
                          Qt Remote Objects (IPC)
                                |
                          logos-cpp-sdk (LogosAPI, types)
```

## Creating a module

```bash
mkdir logos-my-module && cd logos-my-module
nix flake init -t github:logos-co/logos-module-builder        # minimal
nix flake init -t github:logos-co/logos-module-builder#with-external-lib  # wrapping C library
```

Generated structure:
```
flake.nix          # ~15 lines, uses mkLogosModule
module.yaml        # name, version, type, deps, cmake config
CMakeLists.txt     # ~25 lines
src/
  my_module_interface.h   # Q_INVOKABLE methods = public API
  my_module_plugin.h/cpp  # Implementation
```

## module.yaml reference

```yaml
name: my_module
version: 1.0.0
type: core                    # core | ui
category: general             # general | network | chat | wallet | integration
description: "Description"
dependencies: []              # other module names
nix_packages:
  build: []                   # e.g. ["curl"]
  runtime: []
cmake:
  find_packages: []           # e.g. ["CURL"]
  extra_sources: []
  extra_include_dirs: []
  extra_link_libraries: []    # e.g. ["CURL::libcurl"]
```

## Building and testing

```bash
# In workspace — use ws
ws build logos-my-module
ws test logos-my-module
ws build logos-my-module --auto-local   # with local dep overrides

# In the module's own dir
nix build                              # build
nix build .#lib                        # just the .so/.dylib
nix flake check                        # run tests

# Inside dev shell (for CMake iteration)
nix develop
cmake -B build -GNinja && cmake --build build
```

## Inter-module communication (LogosAPI)

Modules call each other via `LogosAPI`:

```cpp
#include <LogosAPI.h>

// Get reference in constructor
LogosAPI* api = LogosAPI::instance();

// Call another module's method
LogosResult result = api->callModule("other_module", "methodName", args);
if (result.success()) {
    QVariant data = result.data();
}
```

### Code generator

Auto-generate type-safe wrappers from a module's metadata:

```bash
logos-cpp-generator <plugin-file> [--output-dir <dir>]
logos-cpp-generator --metadata metadata.json --module-dir <dir>
```

Generates `<ModuleName>Client.h` with typed methods instead of raw string calls.

### LogosResult

All cross-module calls return `LogosResult`:
- `result.success()` / `result.error()` — check outcome
- `result.data()` — return value (QVariant)
- `result.errorMessage()` — error description

## CLI tools

All tools are available directly (or as `ws <tool>`) and auto-build/rebuild from the local repo.

```bash
# Module inspector
lm metadata <plugin-file> [--json]
lm methods <plugin-file> [--json]

# Headless runtime
logoscore -m <modules-dir> --load-modules <name> [-c "<module>.<method>(args)"]

# Package tool
lgx create <output.lgx> --name <name>
lgx add-variant <pkg.lgx> --variant <name> --files <path>
lgx list <pkg.lgx>
lgx verify <pkg.lgx>

# Package manager
lgpm install <pkg>
lgpm install --file <path.lgx>
lgpm search <query>
lgpm list [--installed]

# SDK code generator
logos-cpp-generator <plugin-file> [--output-dir <dir>]
logos-cpp-generator --metadata <metadata.json> --module-dir <dir>
```

## Module types

- **core** — background services, no UI (loaded by logoscore or logos-app)
- **ui** — Qt Widgets or QML-based UI (loaded only by logos-app, displayed in tabbed workspace)

UI modules need `type: ui` in module.yaml and must implement `QWidget* createWidget()` or provide QML.

## Packaging for distribution

Manual packaging with `lgx`:

```bash
# Create .lgx package
lgx create my_module.lgx --name my_module

# Add platform variants
lgx add-variant my_module.lgx --variant linux-x86_64 --files ./result/lib/my_module_plugin.so
lgx add-variant my_module.lgx --variant darwin-arm64 --files ./result/lib/my_module_plugin.dylib

# Install locally
lgpm install --file my_module.lgx
```

Automated Nix-based packaging uses `nix-bundle-lgx` (which uses `nix-bundle-dir` underneath):
- `nix-bundle-dir` — bundles Nix derivations into portable self-contained directories (rewrites rpaths, resolves dependencies)
- `nix-bundle-lgx` — wraps the bundled output into `.lgx` packages with platform variants and metadata
- Bundlers: `default` (requires Nix store at runtime) or `portable` (fully self-contained)

## Common pitfalls

- LogosAPI is only available when loaded by logoscore/logos-app, NOT in module-viewer or standalone
- Module binary name must match `name` in module.yaml (e.g., `my_module` -> `my_module_plugin.so`)
- `metadata.json` must be alongside the binary for discovery
- Always build inside nix (raw cmake won't find Qt/deps)
- After adding `checks` to a repo's flake.nix, run `ws sync-graph`
