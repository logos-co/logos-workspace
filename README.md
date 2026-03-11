# Logos Workspace

Unified multi-repo development environment for the Logos project. All repos live under `repos/` as git submodules. A Nix flake wires them together so that local changes propagate through the dependency chain automatically.

## Quick Start

```bash
# 1. Clone this repo
git clone --recurse-submodules git@github.com:logos-co/logos-workspace.git
cd logos-workspace

# 2. Or if already cloned, initialize submodules
./scripts/ws init

# 3. Add ws to your PATH (or alias it)
alias ws=./scripts/ws
# or: export PATH="$PWD/scripts:$PATH"

# 4. Enter the dev shell (optional, adds ws to PATH automatically)
nix develop
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
| `ws foreach <cmd>` | Run a command in every repo |
| `ws sync-graph` | Regenerate `nix/dep-graph.nix` from repo flake.nix files |

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
- **Modules**: [logos-accounts-module](https://github.com/logos-co/logos-accounts-module), [logos-blockchain-module](https://github.com/logos-blockchain/logos-blockchain-module), [logos-chat-module](https://github.com/logos-co/logos-chat-module), [logos-chat-legacy-module](https://github.com/logos-co/logos-chat-legacy-module), [logos-chatsdk-module](https://github.com/logos-co/logos-chatsdk-module), [logos-irc-module](https://github.com/logos-co/logos-irc-module), [logos-waku-module](https://github.com/logos-co/logos-waku-module), [logos-package-manager-module](https://github.com/logos-co/logos-package-manager-module), [logos-storage-module](https://github.com/logos-co/logos-storage-module), [logos-wallet-module](https://github.com/logos-co/logos-wallet-module), [logos-libp2p-module](https://github.com/logos-co/logos-libp2p-module), [logos-simple-module](https://github.com/logos-co/logos-simple-module), [logos-template-module](https://github.com/logos-co/logos-template-module)
- **Apps**: [logos-app-poc](https://github.com/logos-co/logos-app-poc), [logos-accounts-ui](https://github.com/logos-co/logos-accounts-ui), [logos-chat-tui](https://github.com/logos-co/logos-chat-tui), [logos-chat-ui](https://github.com/logos-co/logos-chat-ui), [logos-chatsdk-ui](https://github.com/logos-co/logos-chatsdk-ui), [logos-waku-ui](https://github.com/logos-co/logos-waku-ui), [logos-package-manager-ui](https://github.com/logos-co/logos-package-manager-ui), [logos-storage-ui](https://github.com/logos-co/logos-storage-ui), [logos-wallet-ui](https://github.com/logos-co/logos-wallet-ui), [logos-webview-app](https://github.com/logos-co/logos-webview-app)
- **UI**: [logos-design-system](https://github.com/logos-co/logos-design-system)
- **SDKs**: [logos-cpp-sdk](https://github.com/logos-co/logos-cpp-sdk), [logos-js-sdk](https://github.com/logos-co/logos-js-sdk), [logos-nim-sdk](https://github.com/logos-co/logos-nim-sdk), [logos-rust-sdk](https://github.com/logos-co/logos-rust-sdk)
- **Docs**: [logos-docs](https://github.com/logos-co/logos-docs), [logos-website](https://github.com/logos-co/logos-website), [logos-tutorial](https://github.com/logos-co/logos-tutorial)
- **Other**: [counter](https://github.com/logos-co/counter), [counter_qml](https://github.com/logos-co/counter_qml), [node-configs](https://github.com/logos-co/node-configs), [logos-modules](https://github.com/logos-co/logos-modules), [logos-module-viewer](https://github.com/logos-co/logos-module-viewer)
