# Logos Workspace

Unified multi-repo development environment for the Logos project. All repos live under `repos/` as git submodules. A Nix flake wires them together so that local changes propagate through the dependency chain automatically.

## Quick Start

```bash
# 1. Clone this repo
git clone --recurse-submodules git@github.com:logos-co/logos-workspace.git
cd logos-workspace

# 2. Or if already cloned, initialize submodules
./scripts/ws init

# 3. Enter the dev shell (optional, adds ws to PATH)
nix develop --extra-experimental-features "nix-command flakes"
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

### Build/Run Options

- `--auto-local`, `-a` — Auto-detect dirty repos and use them as local overrides
- `--local`, `-l <repo1> <repo2> ...` — Explicitly specify local overrides

### Test Options

- `ws test --all` — Run `nix flake check` (all repos)
- `ws test --all --type cpp` — Run checks only for C++ repos
- `ws test logos-cpp-sdk` — Run checks for a specific repo
- Types: `cpp`, `rust`, `nim`, `js`, `qml`

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

- **Foundation**: logos-cpp-sdk, logos-module, logos-liblogos, logos-capability-module, logos-package, logos-module-builder
- **App**: logos-app-poc
- **Modules**: accounts, blockchain, chat, chatsdk, irc, waku, package-manager, storage, wallet, libp2p, simple, template, webview-app
- **UI**: logos-design-system, various *-ui repos
- **SDKs**: logos-cpp-sdk, logos-js-sdk, logos-nim-sdk, logos-rust-sdk
- **Docs**: logos-docs, logos-website, logos-tutorial
- **Other**: counter, counter_qml, node-configs, logos-modules, logos-module-viewer

## Notes

- All sub-repos use branch `master` (not main)
- The HackMD list references `logos-package-manager`, but the actual repo is `logos-package-manager-module`
- `logos-chat-ui` and `logos-irc-module` depend on `logos-chat-legacy-module` (not `logos-chat-module`)
- External dependencies (go-wallet-sdk, logos-delivery, logos-storage-nim, nim-libp2p) are not overridden by the workspace — they use each repo's own pinned versions
- `logos-design-system` originally uses nixos-24.11; the workspace forces nixos-unstable via follows
- Repos without a flake.nix (logos-docs, logos-website, logos-tutorial, logos-template-module, logos-blockchain-module, node-configs) are submodules only — not wired into the Nix dependency graph
