{
  description = "Logos Workspace — unified multi-repo development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ── Shared build tooling (not developed locally, but needed for follows) ──

    nix-bundle-dir.url = "github:logos-co/nix-bundle-dir";
    nix-bundle-appimage.url = "github:logos-co/nix-bundle-appimage";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    nix-bundle-macos-app = {
      url = "github:logos-co/nix-bundle-macos-app";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
    };

    # ── Foundation ────────────────────────────────────────────────────────────
    #
    # logos-cpp-sdk is the root of the dependency tree.
    # Most repos eventually depend on it via logos-liblogos.
    # Overriding logos-cpp-sdk here propagates to ALL downstream consumers
    # thanks to the follows declarations below.

    logos-cpp-sdk = {
      url = "github:logos-co/logos-cpp-sdk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    logos-module = {
      url = "github:logos-co/logos-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    logos-liblogos = {
      url = "github:logos-co/logos-liblogos";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-module.follows = "logos-module";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
      inputs.nix-bundle-appimage.follows = "nix-bundle-appimage";
    };

    logos-capability-module = {
      url = "github:logos-co/logos-capability-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    logos-package = {
      url = "github:logos-co/logos-package";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    logos-module-builder = {
      url = "github:logos-co/logos-module-builder";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    # ── App ───────────────────────────────────────────────────────────────────

    logos-app-poc = {
      url = "github:logos-co/logos-app-poc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-package.follows = "logos-package";
      inputs.logos-package-manager-ui.follows = "logos-package-manager-ui";
      inputs.logos-webview-app.follows = "logos-webview-app";
      inputs.logos-design-system.follows = "logos-design-system";
      inputs.logos-counter-qml.follows = "counter_qml";
      inputs.logos-counter.follows = "counter";
      inputs.nix-bundle-lgx.follows = "nix-bundle-lgx";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
      inputs.nix-bundle-appimage.follows = "nix-bundle-appimage";
      inputs.nix-bundle-macos-app.follows = "nix-bundle-macos-app";
    };

    # ── Modules: Accounts ─────────────────────────────────────────────────────

    logos-accounts-module = {
      url = "github:logos-co/logos-accounts-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # go-wallet-sdk: external dep (status-im org), left as-is
    };

    logos-accounts-ui = {
      url = "github:logos-co/logos-accounts-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-accounts-module.follows = "logos-accounts-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.nix-bundle-lgx.follows = "nix-bundle-lgx";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
    };

    # ── Modules: Chat & Messaging ─────────────────────────────────────────────

    logos-chat-module = {
      url = "github:logos-co/logos-chat-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
    };

    # logos-chat-ui and logos-irc-module depend on the legacy chat module
    logos-chat-legacy-module = {
      url = "github:logos-co/logos-chat-legacy-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
    };

    logos-chat-tui = {
      url = "github:logos-co/logos-chat-tui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-chat-module.follows = "logos-chat-module";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-rust-sdk.follows = "logos-rust-sdk";
    };

    logos-chat-ui = {
      url = "github:logos-co/logos-chat-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # NB: this repo's "logos-chat-module" input actually points to the legacy module
      inputs.logos-chat-module.follows = "logos-chat-legacy-module";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-chatsdk-module = {
      url = "github:logos-co/logos-chatsdk-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-chat: external dep (logos-messaging org), left as-is
    };

    logos-chatsdk-ui = {
      url = "github:logos-co/logos-chatsdk-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-chatsdk-module.follows = "logos-chatsdk-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-irc-module = {
      url = "github:logos-co/logos-irc-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # NB: this repo's "logos-chat-module" input actually points to the legacy module
      inputs.logos-chat-module.follows = "logos-chat-legacy-module";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Waku ─────────────────────────────────────────────────────────

    logos-waku-module = {
      url = "github:logos-co/logos-waku-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-delivery: external dep (logos-messaging org), left as-is
    };

    logos-waku-ui = {
      url = "github:logos-co/logos-waku-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Package Manager ──────────────────────────────────────────────

    logos-package-manager-module = {
      url = "github:logos-co/logos-package-manager-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-package.follows = "logos-package";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
      inputs.nix-bundle-appimage.follows = "nix-bundle-appimage";
    };

    logos-package-manager-ui = {
      url = "github:logos-co/logos-package-manager-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-package-manager-module.follows = "logos-package-manager-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Storage ──────────────────────────────────────────────────────

    logos-storage-module = {
      url = "github:logos-co/logos-storage-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-storage: external dep (logos-storage org), left as-is
    };

    logos-storage-ui = {
      url = "github:logos-co/logos-storage-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-storage-module.follows = "logos-storage-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-design-system.follows = "logos-design-system";
    };

    # ── Modules: Wallet ───────────────────────────────────────────────────────

    logos-wallet-module = {
      url = "github:logos-co/logos-wallet-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # go-wallet-sdk: external dep (status-im org), left as-is
    };

    logos-wallet-ui = {
      url = "github:logos-co/logos-wallet-ui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-wallet-module.follows = "logos-wallet-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Other ────────────────────────────────────────────────────────

    logos-libp2p-module = {
      url = "github:logos-co/logos-libp2p-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-module-builder.follows = "logos-module-builder";
      # libp2p: external dep (vacp2p org), left as-is
    };

    logos-simple-module = {
      url = "github:logos-co/logos-simple-module";
      # NB: This repo uses flake=false for its deps (pinned source, not flake inputs).
      # Follows won't propagate here — it's effectively standalone.
    };

    logos-webview-app = {
      url = "github:logos-co/logos-webview-app";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    counter_qml = {
      url = "github:logos-co/counter_qml";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    counter = {
      url = "github:logos-co/counter";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    # ── UI ────────────────────────────────────────────────────────────────────

    logos-design-system = {
      url = "github:logos-co/logos-design-system";
      # NB: Originally uses nixos-24.11; following unstable may need attention
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── SDKs ──────────────────────────────────────────────────────────────────

    logos-js-sdk = {
      url = "github:logos-co/logos-js-sdk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-nim-sdk = {
      url = "github:logos-co/logos-nim-sdk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    logos-rust-sdk = {
      url = "github:logos-co/logos-rust-sdk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Other ─────────────────────────────────────────────────────────────────

    logos-modules = {
      url = "github:logos-co/logos-modules";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-package.follows = "logos-package";
    };

    logos-module-viewer = {
      url = "github:logos-co/logos-module-viewer";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
    };

    # Repos with no flake.nix (submodules only, not flake inputs):
    #   logos-docs, logos-website, logos-tutorial, logos-template-module,
    #   logos-blockchain-module, node-configs
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = fn: nixpkgs.lib.genAttrs systems fn;

      # Every logos flake input (for iteration).  Repos without a flake.nix
      # are NOT listed here — they are submodules only.
      repoInputNames = [
        # Foundation
        "logos-cpp-sdk" "logos-module" "logos-liblogos"
        "logos-capability-module" "logos-package" "logos-module-builder"
        # App
        "logos-app-poc"
        # Accounts
        "logos-accounts-module" "logos-accounts-ui"
        # Chat & Messaging
        "logos-chat-module" "logos-chat-legacy-module" "logos-chat-tui"
        "logos-chat-ui" "logos-chatsdk-module" "logos-chatsdk-ui" "logos-irc-module"
        # Waku
        "logos-waku-module" "logos-waku-ui"
        # Package Manager
        "logos-package-manager-module" "logos-package-manager-ui"
        # Storage
        "logos-storage-module" "logos-storage-ui"
        # Wallet
        "logos-wallet-module" "logos-wallet-ui"
        # Other modules
        "logos-libp2p-module" "logos-simple-module" "logos-webview-app"
        "counter_qml" "counter"
        # UI
        "logos-design-system"
        # SDKs
        "logos-js-sdk" "logos-nim-sdk" "logos-rust-sdk"
        # Other
        "logos-modules" "logos-module-viewer"
      ];

      # Mapping from flake input name → submodule directory name under repos/
      # Only entries where the names differ need to be listed.
      inputToDirOverrides = {
        "counter_qml" = "counter_qml";
        "counter" = "counter";
        "logos-chat-legacy-module" = "logos-chat-legacy-module";
        "logos-package-manager-module" = "logos-package-manager-module";
      };

      inputToDir = name: inputToDirOverrides.${name} or name;

    in {

      # ── Packages ──────────────────────────────────────────────────────────
      # nix build .#logos-cpp-sdk
      # nix build .#logos-app-poc
      packages = forAllSystems (system:
        builtins.listToAttrs (builtins.concatMap (name:
          let
            result = builtins.tryEval (
              (inputs.${name}.packages.${system} or {}).default or null
            );
            pkg = if result.success then result.value else null;
          in
          if pkg != null then [{ inherit name; value = pkg; }] else []
        ) repoInputNames)
      );

      # ── Dev Shells ────────────────────────────────────────────────────────
      # nix develop          → workspace shell (ws CLI + common tools)
      # nix develop .#logos-cpp-sdk → that repo's own devShell
      # nix develop          → workspace shell with ws CLI + common tools
      # For sub-repo devShells use: nix develop path:./repos/<repo-name>
      #   or: ws develop <repo-name>
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          wsScript = pkgs.writeShellScriptBin "ws" (builtins.readFile ./scripts/ws);

        in {
          default = pkgs.mkShell {
            name = "logos-workspace";
            packages = with pkgs; [
              git
              jq
              nix
              wsScript
            ];
            shellHook = ''
              export LOGOS_WORKSPACE_ROOT="${toString ./.}"
              echo "Logos Workspace — run 'ws help' for commands"
            '';
          };
        }
      );

      # ── Checks ────────────────────────────────────────────────────────────
      # nix flake check        → run ALL repo checks
      # nix build .#checks.x86_64-linux.logos-cpp-sdk--test
      checks = forAllSystems (system:
        builtins.foldl' (acc: name:
          let
            result = builtins.tryEval (inputs.${name}.checks.${system} or {});
            repoChecks = if result.success then result.value else {};
            prefixed = nixpkgs.lib.mapAttrs'
              (cname: drv: { name = "${name}--${cname}"; value = drv; })
              repoChecks;
          in
          acc // prefixed
        ) {} repoInputNames
      );

      # ── Lib (for programmatic use) ────────────────────────────────────────
      lib = {
        inherit repoInputNames inputToDir;
        # Dependency graph: input name → list of logos input names it depends on
        depGraph = import ./nix/dep-graph.nix;
      };
    };
}
