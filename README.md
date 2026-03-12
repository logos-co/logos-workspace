# Logos Workspace

Unified multi-repo development environment for the Logos project. All ~43 repos live under `repos/` as git submodules. A Nix flake wires them together so that local changes propagate through the dependency chain automatically.

## Quick Start

```bash
# 1. Clone this repo
git clone --recurse-submodules git@github.com:logos-co/logos-workspace.git
cd logos-workspace

# 2. Or if already cloned, initialize submodules
./scripts/ws init

# 3. Add scripts to your PATH (ws + CLI tools like lm, lgx, logoscore)
export PATH="$PWD/scripts:$PATH"
# Add this to your ~/.zshrc or ~/.bashrc with the full path to persist it

# 4. Enter the dev shell (optional, adds ws to PATH automatically)
ws develop
```

### Enabling Nix flakes

The examples in this README assume flakes are enabled globally. If they aren't, you can pass the flags explicitly:

```bash
nix build '.#logos-liblogos' --extra-experimental-features 'nix-command flakes'
```

To enable globally so you don't need these flags for each command, add the following to `~/.config/nix/nix.conf` (create the file if it doesn't exist):

```
experimental-features = nix-command flakes
```

## The Key Feature: Local Dependency Overrides

The workspace flake uses `follows` declarations to create a single dependency graph. When you override one input, the change propagates to every downstream consumer automatically.

**Example**: Edit `logos-cpp-sdk`, then build `logos-app-poc` using your local version:

```bash
# Edit something in logos-cpp-sdk
vim repos/logos-cpp-sdk/src/something.cpp

# Build logos-app-poc — it will use YOUR local logos-cpp-sdk,
# and so will every intermediate dep (logos-liblogos, logos-module, etc.)
ws build logos-app-poc --auto-local

# Or be explicit about which repos to override
ws build logos-app-poc --local logos-cpp-sdk logos-liblogos
```

The `--auto-local` flag detects all repos with uncommitted changes and generates the appropriate `--override-input` flags.

### How it works

Under the hood, `ws build logos-app-poc --local logos-cpp-sdk` runs:

```bash
nix build .#logos-app-poc \
  --override-input logos-cpp-sdk path:./repos/logos-cpp-sdk
```

Because the workspace flake declares `logos-liblogos.inputs.logos-cpp-sdk.follows = "logos-cpp-sdk"` (and similar for all other repos), this single override propagates through the entire dependency tree. You don't need to override each intermediate dependency separately.

## Commands

| Command | Description |
|---------|-------------|
| `ws init [jobs]` | Clone all submodules (default: 4 parallel jobs) |
| `ws list` | List all repos and their clone/flake status |
| `ws build <repo> [opts]` | Build a repo via nix |
| `ws run <repo> [opts]` | Build and run a repo |
| `ws develop [repo] [opts]` | Enter a nix devShell |
| `ws test [repo\|--all] [--type T]` | Run checks/tests |
| `ws status` | Git status across all repos |
| `ws dirty` | Show dirty repos and what they affect |
| `ws graph [repo]` | Show dependency graph |
| `ws override-inputs <repo> [opts]` | Preview override flags |
| `ws update [repo\|--all]` | Update flake.lock inputs |
| `ws loc [repo\|--all] [--no-nix]` | Count lines of code (uses tokei) |
| `ws watch test <repo>` | Re-run tests on file changes |
| `ws watch build <repo>` | Re-build on file changes |
| `ws watch run <cmd> [-w repo]` | Run command on file changes |
| `ws foreach <cmd>` | Run a command in every repo |
| `ws worktree add <name> [-b br]` | Create a worktree with submodules and `ws/<branch>` branches |
| `ws worktree list` | List all worktrees |
| `ws worktree remove <name>` | Remove a worktree |
| `ws sync-graph` | Regenerate `nix/dep-graph.nix` from repo flake.nix files |

### Global Options

- `--quiet`, `-q` — Suppress informational output (headers, progress, hints) and strip colors. Useful for CI pipelines and scripting. Primary output (test results, status lines, data) is still shown.

```bash
# Machine-friendly status output (no colors, no header)
ws --quiet status

# Quiet test run — only PASS/FAIL lines and summary
ws test --all --quiet
```

### CLI Tools

These are also in `scripts/` and auto-build from the local repo on first use. They rebuild automatically when source files change. All are also available as `ws` subcommands (e.g. `ws lgx`, `ws lm`, `ws logoscore`).

#### `logoscore` — headless module runtime (logos-liblogos)

Loads modules and calls their methods without the full GUI. Essential for testing.

```
logoscore [options]
  -m, --modules-dir <path>         Directory to scan for plugins (repeatable)
  -l, --load-modules <mod1,mod2>   Comma-separated modules to load (auto-resolves deps)
  -c, --call <module.method(args)> Call a method after loading (repeatable, sequential)
  -h, --help                       Show help
  --version                        Show version
```

Method call syntax for `-c`: `module_name.method(arg1, arg2)`
- Type auto-detection: `true`/`false` → bool, `42` → int, `3.14` → double, else → string
- `@filename` reads file content as the argument (e.g. `@config.json` for JSON configs)
- 30-second timeout per call; exit code 1 on any failure

```bash
# Load a module (auto-resolves transitive dependencies)
logoscore -m ./modules --load-modules my_module

# Load and call a method
logoscore -m ./modules -l my_module -c "my_module.doSomething(hello)"

# Sequential calls with a file parameter
logoscore -m ./modules -l storage_module \
  -c "storage_module.init(@config.json)" \
  -c "storage_module.start()"

# Multiple modules — dependencies resolved automatically
logoscore -m ./modules -l waku_module,chat,my_module
```

#### `lm` — module inspector (logos-module)

Introspects compiled Qt plugin files to show metadata and method signatures.

```
lm [command] <plugin-path> [options]

Commands:
  (default)    Show both metadata and methods
  metadata     Show plugin metadata only (name, version, description, author, type, deps)
  methods      Show exposed Q_INVOKABLE methods only (name, signature, return type, params)

Options:
  --json       Output structured JSON
  --debug      Show Qt debug output during plugin loading
  -h, --help
  -v, --version
```

```bash
lm ./result/lib/my_module_plugin.so                    # everything
lm metadata ./result/lib/my_module_plugin.so           # metadata only
lm methods ./result/lib/my_module_plugin.so --json     # methods as JSON
```

#### `lgx` — LGX package tool (logos-package)

Creates and manages `.lgx` packages (gzip tar archives with platform-specific variants).

```
lgx <command> [options]

Commands:
  create <name>                     Create empty .lgx package
  add <pkg> -v <variant> -f <path>  Add files to a variant (replaces if exists)
    --variant, -v <name>              e.g. linux-x86_64, darwin-arm64
    --files, -f <path>                File or directory to add
    --main, -m <relpath>              Main entry point (required if --files is a dir)
    --yes, -y                         Skip confirmation prompts
  remove <pkg> -v <variant>         Remove a variant
  extract <pkg> [-v <variant>] [-o <dir>]  Extract variant(s)
  verify <pkg>                      Validate against LGX spec
  sign <pkg>                        (not yet implemented)
  publish <pkg>                     (not yet implemented)
```

```bash
lgx create my_module
lgx add my_module.lgx -v linux-x86_64 -f ./result/lib/my_module_plugin.so
lgx add my_module.lgx -v darwin-arm64 -f ./result/lib/my_module_plugin.dylib
lgx verify my_module.lgx
lgx extract my_module.lgx -v linux-x86_64 -o ./extracted
```

#### `lgpm` — package manager (logos-package-manager-module)

Installs, searches, and manages module packages. Fetches from GitHub releases with automatic dependency resolution.

```
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
  install <pkg> [pkgs...]    Install packages (auto-resolves deps)
    --file <path>              Install from local .lgx file instead
```

```bash
lgpm search waku
lgpm list --installed
lgpm info my_module
lgpm --modules-dir ./modules install my_module             # from registry
lgpm --modules-dir ./modules install --file ./my_module.lgx  # from local file
lgpm --modules-dir ./modules --release v2.0.0 install my_module
```

### Build/Run Options

- `--auto-local`, `-a` — Auto-detect dirty repos and use them as local overrides
- `--local`, `-l <repo1> <repo2> ...` — Explicitly specify local overrides

### Test Options

- `ws test --all` — Run `nix flake check` (all repos)
- `ws test --all --type cpp` — Run checks only for C++ repos
- `ws test logos-cpp-sdk` — Run checks for a specific repo
- Types: `cpp`, `rust`, `nim`, `js`, `qml`

## Adding Tests to a Repo

Repos that expose tests follow two conventions so that `ws test` can discover and run them:

1. **Add a `checks.<system>.tests` output** to the repo's `flake.nix`. This derivation should build *and run* the test binary (not just compile it). See `repos/logos-liblogos/flake.nix` or `repos/logos-module/flake.nix` for examples.

2. **Run `ws sync-graph`** to regenerate `nix/dep-graph.nix`. This scans every repo's `flake.nix` to detect deps and whether it has a `checks` output (`hasTests`). Without `hasTests = true`, `ws test` skips the repo entirely to avoid expensive nix evaluation.

```bash
# After adding checks to a repo's flake.nix:
ws sync-graph
```

Repos with `hasTests = false` (the default for most repos) are skipped by `ws test --all`.

## Using nix directly

The workspace flake re-exports everything from the sub-repo flakes:

```bash
# Build any repo
nix build .#logos-cpp-sdk
nix build .#logos-app-poc

# Enter a repo's own devShell
nix develop path:./repos/logos-cpp-sdk
# or: ws develop logos-cpp-sdk

# Run all checks
nix flake check

# Manual override
nix build .#logos-app-poc \
  --override-input logos-cpp-sdk path:./repos/logos-cpp-sdk \
  --override-input logos-liblogos path:./repos/logos-liblogos
```

## Dependency Graph

```
nixpkgs
  └── logos-cpp-sdk
        ├── logos-module
        ├── counter, counter_qml
        └── logos-liblogos
              ├── logos-capability-module
              ├── logos-package → logos-package-manager-module → logos-package-manager-ui
              │                 └── nix-bundle-lgx (LGX bundler, uses nix-bundle-dir)
              ├── nix-bundle-dir (portable bundling for Nix derivations)
              ├── logos-module-builder → logos-libp2p-module
              ├── logos-webview-app
              ├── logos-waku-module → logos-chat-module, logos-chat-legacy-module,
              │                       logos-waku-ui, logos-chat-tui, logos-chat-ui,
              │                       logos-irc-module
              ├── logos-accounts-module → logos-accounts-ui
              ├── logos-wallet-module → logos-wallet-ui
              ├── logos-storage-module → logos-storage-ui
              ├── logos-chatsdk-module → logos-chatsdk-ui
              ├── logos-module-viewer
              ├── logos-nim-sdk, logos-js-sdk
              └── logos-app-poc (aggregates many of the above)

  Standalone: logos-rust-sdk, logos-design-system, logos-simple-module
```

Generate a visual graph: `ws graph | dot -Tsvg > graph.svg`

## Repo Categories

- **Foundation**: [logos-cpp-sdk](https://github.com/logos-co/logos-cpp-sdk), [logos-module](https://github.com/logos-co/logos-module), [logos-liblogos](https://github.com/logos-co/logos-liblogos), [logos-capability-module](https://github.com/logos-co/logos-capability-module), [logos-package](https://github.com/logos-co/logos-package), [logos-module-builder](https://github.com/logos-co/logos-module-builder)
- **Packaging**: [nix-bundle-dir](https://github.com/logos-co/nix-bundle-dir), [nix-bundle-lgx](https://github.com/logos-co/nix-bundle-lgx)
- **Modules**: [logos-accounts-module](https://github.com/logos-co/logos-accounts-module), [logos-blockchain-module](https://github.com/logos-blockchain/logos-blockchain-module), [logos-chat-module](https://github.com/logos-co/logos-chat-module), [logos-chat-legacy-module](https://github.com/logos-co/logos-chat-legacy-module), [logos-chatsdk-module](https://github.com/logos-co/logos-chatsdk-module), [logos-irc-module](https://github.com/logos-co/logos-irc-module), [logos-waku-module](https://github.com/logos-co/logos-waku-module), [logos-package-manager-module](https://github.com/logos-co/logos-package-manager-module), [logos-storage-module](https://github.com/logos-co/logos-storage-module), [logos-wallet-module](https://github.com/logos-co/logos-wallet-module), [logos-libp2p-module](https://github.com/logos-co/logos-libp2p-module), [logos-simple-module](https://github.com/logos-co/logos-simple-module), [logos-template-module](https://github.com/logos-co/logos-template-module)
- **Apps**: [logos-app-poc](https://github.com/logos-co/logos-app-poc), [logos-accounts-ui](https://github.com/logos-co/logos-accounts-ui), [logos-chat-tui](https://github.com/logos-co/logos-chat-tui), [logos-chat-ui](https://github.com/logos-co/logos-chat-ui), [logos-chatsdk-ui](https://github.com/logos-co/logos-chatsdk-ui), [logos-waku-ui](https://github.com/logos-co/logos-waku-ui), [logos-package-manager-ui](https://github.com/logos-co/logos-package-manager-ui), [logos-storage-ui](https://github.com/logos-co/logos-storage-ui), [logos-wallet-ui](https://github.com/logos-co/logos-wallet-ui), [logos-webview-app](https://github.com/logos-co/logos-webview-app)
- **UI**: [logos-design-system](https://github.com/logos-co/logos-design-system)
- **SDKs**: [logos-cpp-sdk](https://github.com/logos-co/logos-cpp-sdk), [logos-js-sdk](https://github.com/logos-co/logos-js-sdk), [logos-nim-sdk](https://github.com/logos-co/logos-nim-sdk), [logos-rust-sdk](https://github.com/logos-co/logos-rust-sdk)
- **Docs**: [logos-docs](https://github.com/logos-co/logos-docs), [logos-website](https://github.com/logos-co/logos-website), [logos-tutorial](https://github.com/logos-co/logos-tutorial)
- **Other**: [counter](https://github.com/logos-co/counter), [counter_qml](https://github.com/logos-co/counter_qml), [node-configs](https://github.com/logos-co/node-configs), [logos-modules](https://github.com/logos-co/logos-modules), [logos-module-viewer](https://github.com/logos-co/logos-module-viewer)

# Workflows

## Developing a library and testing it in a downstream app

The most common workflow: you're changing a library (e.g. `logos-cpp-sdk`) and want to see the effect in something that uses it (e.g. `logos-liblogos` or `logos-app-poc`).

```bash
# 1. Make your changes
cd repos/logos-cpp-sdk
vim cpp/logos_api.h

# 2. Build a downstream repo using your local changes
ws build logos-liblogos --auto-local

# 3. Or test a downstream repo with your changes
ws test logos-liblogos --auto-local

# 4. Check what else your changes affect
ws dirty
```

`--auto-local` detects every dirty repo and overrides it in the build. If you only want to override specific repos:

```bash
ws build logos-app-poc --local logos-cpp-sdk logos-liblogos
```

## Running tests

```bash
# Test a single repo
ws test logos-module

# Test all repos that have tests
ws test --all

# Test only C++ repos
ws test --all --type cpp

# Test only Rust repos
ws test --all --type rust
```

`ws test` only runs repos that have `hasTests = true` in `nix/dep-graph.nix`. Repos without tests are skipped instantly.

## Watching for changes

Auto-run tests or builds whenever you save a file — no manual re-running:

```bash
# Re-run tests every time you save a file in logos-module
ws watch test logos-module

# Auto-build with local overrides on save
ws watch build logos-app-poc --auto-local

# Watch specific repos and run a custom command
ws watch run 'ws test logos-module --auto-local' -w logos-module -w logos-cpp-sdk
```

Combine with `--auto-local` to get a live feedback loop: edit a library, save, and see the downstream build or test result immediately.

## Running an app with local changes

```bash
# Build and run logos-app-poc using your local logos-cpp-sdk
ws run logos-app-poc --auto-local

# Or with explicit overrides
ws run logos-app-poc --local logos-cpp-sdk logos-liblogos
```

## Checking what your changes affect

Before pushing, see which repos depend on the code you changed:

```bash
# Show all dirty repos and their downstream dependents
ws dirty

# Show the full dependency tree for a specific repo
ws graph logos-cpp-sdk

# Preview the exact nix --override-input flags that would be used
ws override-inputs logos-app-poc --auto-local
```

## Keeping repos up to date

```bash
# Pull latest code in every repo
ws foreach git pull

# Update a single flake input to its latest upstream
ws update logos-cpp-sdk

# Update all flake inputs
ws update --all

# Check clone/branch status across all repos
ws status
```

## Working across multiple repos at once

```bash
# Run any command in every repo
ws foreach git status -s
ws foreach git stash

# Chain multiple commands with quotes (|| true skips repos where nothing happens)
ws foreach 'git add . && git commit -m "your commit message" || true'

# Check which repos have local changes or unpushed commits
ws status
```

## Working in isolated worktrees

Use worktrees to work on feature branches that span multiple repos without disturbing your main workspace:

```bash
# Create a worktree for a feature branch
ws worktree add my-feature -b my-feature-branch
# Creates ../logos-workspace--my-feature/ with:
#   - Workspace on branch: my-feature-branch
#   - All repos on branch: ws/my-feature-branch

# Work in the worktree
cd ../logos-workspace--my-feature
# Make changes in repos/logos-cpp-sdk, repos/logos-liblogos, etc.
ws build logos-app-poc --auto-local

# Commit and push changes in modified repos
ws foreach 'git add . && git commit -m "my changes" && git push origin ws/my-feature-branch || true'

# When done, remove the worktree
cd ../logos-workspace
ws worktree remove my-feature
```

For **claude-docker** or similar tools: the repo includes `.claude-docker/post-worktree.sh` which automatically initializes submodules and creates `ws/<branch>` branches after a worktree is created.
## Entering a dev shell

The workspace dev shell comes with modern CLI tools (eza, bat, fzf, delta, starship, zoxide, neovim) and handy aliases (`gst`, `ga`, `gc`, `gd`, `gl`, `wss`, `wsd`, etc.).

For the best experience, install a [Nerd Font](https://www.nerdfonts.com/font-downloads) (e.g. [FiraCode Nerd Font](https://www.nerdfonts.com/font-downloads)) and set it as your terminal font. This enables file icons in `ls` and other tools.

```bash
# Workspace dev shell (has ws on PATH)
ws develop

# A specific repo's dev shell (has that repo's build tools)
ws develop logos-module

# Dev shell with local overrides for dirty repos
ws develop logos-app-poc --auto-local
```

## Lines of code

```bash
# Full breakdown for the whole workspace
ws loc

# Lines of code for a single repo
ws loc logos-cpp-sdk

# Per-repo breakdown sorted by LOC
ws loc --all

# Exclude nix/config files — just the actual code
ws loc --all --no-nix
```

## Visualizing the dependency graph

```bash
# Print DOT format to stdout
ws graph

# Generate an SVG
ws graph | dot -Tsvg > graph.svg

# See deps and dependents of a specific repo
ws graph logos-liblogos
```

## Listing repos

```bash
# See which repos are cloned and which have flakes
ws list
```

## Adding tests to a repo

When a repo gains tests for the first time:

1. Add a `checks.<system>.tests` output to the repo's `flake.nix`. This derivation should build **and run** the tests, not just compile them. Example from `logos-module/flake.nix`:

```nix
checks = forAllSystems ({ pkgs }:
  let
    common = import ./nix/default.nix { inherit pkgs; };
    src = ./.;
  in {
    tests = import ./nix/all.nix { inherit pkgs common src; };
  }
);
```

2. Regenerate the dependency graph so `ws test` picks it up:

```bash
ws sync-graph
```

3. Verify it works:

```bash
ws test <your-repo>
```

## Updating the dependency graph

After adding a new repo, changing a repo's flake inputs, or adding tests:

```bash
ws sync-graph
```

This scans every repo's `flake.nix` and regenerates `nix/dep-graph.nix` with accurate `deps` and `hasTests` values. Commit the result.

## Adding a new repo to the workspace

1. Add the git submodule:

```bash
git submodule add --depth 1 git@github.com:logos-co/my-new-repo.git repos/my-new-repo
```

2. Add an entry to the `REPOS` array in `scripts/ws` (follow the existing format).

3. If the repo has a `flake.nix`, add it as an input in the workspace `flake.nix` with appropriate `follows` declarations so its deps chain through the workspace:

```nix
my-new-repo = {
  url = "github:logos-co/my-new-repo";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.logos-liblogos.follows = "logos-liblogos";
  # ... other follows as needed
};
```

4. Regenerate the dependency graph:

```bash
ws sync-graph
```

5. Commit the changes to `.gitmodules`, `flake.nix`, `scripts/ws`, and `nix/dep-graph.nix`.

## Removing a repo from the workspace

```bash
# 1. Remove the submodule
git submodule deinit -f repos/my-repo
git rm -f repos/my-repo
rm -rf .git/modules/repos/my-repo

# 2. Remove its entry from the REPOS array in scripts/ws
# 3. Remove its input and follows declarations from flake.nix
# 4. Regenerate the dependency graph
ws sync-graph

# 5. Commit all changes
```

## Debugging overrides

If `--auto-local` overrides something you didn't intend (e.g. you have a stale change in a repo):

```bash
# See exactly which repos are dirty and why
ws status

# Preview the override flags without building
ws override-inputs logos-app-poc --auto-local

# Use --local instead to control exactly what gets overridden
ws build logos-app-poc --local logos-cpp-sdk
```

If a build fails unexpectedly with overrides, check that the dirty repo is in a buildable state — `--auto-local` uses whatever is on disk, including broken or half-finished work.

## CI

The workspace has GitHub Actions CI (`.github/workflows/ci.yml`) that runs on pull requests to `master`:

- **Change detection** — identifies which repos changed (submodule pointer diffs) and expands to include downstream dependents via `dep-graph.nix`
- **Infrastructure changes** (flake.nix, nix/, scripts/) trigger a build of the core chain: logos-cpp-sdk, logos-module, logos-liblogos, logos-package, logos-app-poc
- **Repo changes** trigger builds of only the affected repos and their dependents
- **Docs-only PRs** (.md/.txt) skip builds entirely
- **Validates** that `dep-graph.nix` is up to date (`ws sync-graph` produces no diff)
- **Runs all tests** via `ws test --all`

## Dev Shell Quick Reference

`ws develop` drops you into a modern shell environment with zsh, tmux, and a curated set of tools. For the best experience, install a [Nerd Font](https://www.nerdfonts.com/font-downloads) (e.g. Monaco Nerd Font or FiraCode Nerd Font).

The first run takes a few seconds while nix fetches the tools. After that, the shell is cached and starts near-instantly. Use `ws develop --fresh` to force rebuild the shell if you've changed the configuration.

### Tmux

| Shortcut | Action |
|----------|--------|
| `Ctrl-A \|` | Split pane horizontally |
| `Ctrl-A -` | Split pane vertically |
| `Ctrl-A c` | New tab |
| `Ctrl-A n` / `Ctrl-A p` | Next / previous tab |
| `Ctrl-A 1-9` | Switch to tab by number |
| `Ctrl-A h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl-A d` | Detach (re-enter with `ws develop`) |
| `Ctrl-A z` | Zoom current pane (toggle fullscreen) |

### Fuzzy Finder & Navigation

| Shortcut / Command | Action |
|---------------------|--------|
| `Ctrl-R` | Fuzzy search command history |
| `Ctrl-T` | Fuzzy find files |
| `z <partial>` | Jump to a previously visited directory |

### File & Directory Commands

| Command | Tool | Description |
|---------|------|-------------|
| `ls` | eza | File listing with icons (supports `-ltra`, `-la`, etc.) |
| `ll` | eza | Long listing with all files |
| `lt` | eza | Tree view (3 levels deep) |
| `cat <file>` | bat | Syntax-highlighted file viewer |
| `less <file>` | bat | Paged syntax-highlighted viewer |
| `rg <pattern>` | ripgrep | Fast recursive search |
| `fd <pattern>` | fd | Fast file finder |
| `dust <dir>` | dust | Visual disk usage |
| `duf` | duf | Disk free overview |

### Git Aliases

| Alias | Command |
|-------|---------|
| `gst` | `git status` |
| `gs` | `git status -s` |
| `ga` | `git add` |
| `gc` | `git commit` |
| `gcm` | `git commit -m` |
| `gd` | `git diff` (side-by-side via delta) |
| `gds` | `git diff --staged` |
| `gl` | `git log --oneline --graph --decorate` |
| `glog` | `git log --graph --oneline --all` |
| `gp` | `git pull` |
| `gps` | `git push` |
| `gco` | `git checkout` |
| `gb` | `git branch` |

### Workspace Aliases

| Alias | Command |
|-------|---------|
| `wss` | `ws status` |
| `wsb` | `ws build` |
| `wst` | `ws test` |
| `wsd` | `ws dirty` |
| `wsg` | `ws graph` |

### Other Tools

```bash
# Render a markdown file
glow README.md

# Interactive git TUI
lazygit
```
