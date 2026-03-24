{
  description = "Logos Workspace — unified multi-repo development environment";

  inputs = {
    # ── Shared Nix infrastructure ─────────────────────────────────────────────
    logos-nix.url = "github:logos-co/logos-nix";

    # ── nixpkgs ────────────────────────────────────────────────────────────────
    # Follows logos-nix's pinned nixpkgs so that ALL repos use the same
    # Qt version and system libraries.  Do NOT pin a separate nixpkgs here.
    nixpkgs.follows = "logos-nix/nixpkgs";

    # ── Shared build tooling (not developed locally, but needed for follows) ──

    nix-bundle-appimage.url = "github:logos-co/nix-bundle-appimage";
    nix-bundle-macos-app = {
      url = "github:logos-co/nix-bundle-macos-app";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
    };

    # ── Packaging / Bundling ───────────────────────────────────────────────────

    nix-bundle-dir = {
      url = "github:logos-co/nix-bundle-dir";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-bundle-lgx = {
      url = "github:logos-co/nix-bundle-lgx";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-package.follows = "logos-package";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
    };

    # ── Foundation ────────────────────────────────────────────────────────────
    #
    # logos-cpp-sdk is the root of the dependency tree.  Its pinned nixpkgs
    # is the single source of truth for Qt and system library versions.
    # Overriding logos-cpp-sdk here propagates to ALL downstream consumers
    # thanks to the follows declarations below.

    logos-cpp-sdk = {
      url = "github:logos-co/logos-cpp-sdk";
      inputs.logos-nix.follows = "logos-nix";
    };

    logos-module = {
      url = "github:logos-co/logos-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    logos-liblogos = {
      url = "github:logos-co/logos-liblogos";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-module.follows = "logos-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-logoscore-cli = {
      url = "github:logos-co/logos-logoscore-cli";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
      inputs.nix-bundle-appimage.follows = "nix-bundle-appimage";
    };

    logos-capability-module = {
      url = "github:logos-co/logos-capability-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-module.follows = "logos-module";
    };

    logos-package = {
      url = "github:logos-co/logos-package";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    logos-module-builder = {
      url = "github:logos-co/logos-module-builder";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-module.follows = "logos-module";
    };

    # ── App ───────────────────────────────────────────────────────────────────

    logos-standalone-app = {
      url = "github:logos-co/logos-standalone-app";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-design-system.follows = "logos-design-system";
    };

    logos-basecamp = {
      url = "github:logos-co/logos-basecamp";
      inputs.logos-nix.follows = "logos-nix";
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
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # go-wallet-sdk: external dep (status-im org), left as-is
    };

    logos-accounts-ui = {
      url = "github:logos-co/logos-accounts-ui";
      inputs.logos-nix.follows = "logos-nix";
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
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
    };

    # logos-chat-ui and logos-irc-module depend on the legacy chat module
    logos-chat-legacy-module = {
      url = "github:logos-co/logos-chat-legacy-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
    };

    logos-chat-tui = {
      url = "github:logos-co/logos-chat-tui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-chat-module.follows = "logos-chat-module";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-rust-sdk.follows = "logos-rust-sdk";
    };

    logos-chat-ui = {
      url = "github:logos-co/logos-chat-ui";
      inputs.logos-nix.follows = "logos-nix";
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
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-chat: external dep (logos-messaging org), left as-is
    };

    logos-chatsdk-ui = {
      url = "github:logos-co/logos-chatsdk-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-chatsdk-module.follows = "logos-chatsdk-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-irc-module = {
      url = "github:logos-co/logos-irc-module";
      inputs.logos-nix.follows = "logos-nix";
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
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-delivery: external dep (logos-messaging org), left as-is
    };

    logos-waku-ui = {
      url = "github:logos-co/logos-waku-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-waku-module.follows = "logos-waku-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Package Manager ──────────────────────────────────────────────

    logos-package-manager-module = {
      url = "github:logos-co/logos-package-manager-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-module.follows = "logos-module";
      inputs.logos-package.follows = "logos-package";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
      inputs.nix-bundle-appimage.follows = "nix-bundle-appimage";
    };

    logos-package-manager-ui = {
      url = "github:logos-co/logos-package-manager-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-package-manager-module.follows = "logos-package-manager-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Storage ──────────────────────────────────────────────────────

    logos-storage-module = {
      url = "github:logos-co/logos-storage-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # logos-storage: external dep (logos-storage org), left as-is
    };

    logos-storage-ui = {
      url = "github:logos-co/logos-storage-ui";
      inputs.logos-nix.follows = "logos-nix";
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
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      # go-wallet-sdk: external dep (status-im org), left as-is
    };

    logos-wallet-ui = {
      url = "github:logos-co/logos-wallet-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-wallet-module.follows = "logos-wallet-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    # ── Modules: Blockchain / Execution zone (LEX) ─────────────────────────────

    logos-blockchain-module = {
      url = "github:logos-blockchain/logos-blockchain-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-core.follows = "logos-cpp-sdk";
      inputs.logos-module-viewer.follows = "logos-module-viewer";
      # logos-blockchain (Rust): external, left as-is
    };

    logos-blockchain-ui = {
      url = "github:logos-blockchain/logos-blockchain-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-blockchain-module.follows = "logos-blockchain-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-design-system.follows = "logos-design-system";
    };

    logos-execution-zone-module = {
      url = "github:logos-blockchain/logos-execution-zone-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-core.follows = "logos-cpp-sdk";
      inputs.logos-module-viewer.follows = "logos-module-viewer";
      # logos-execution-zone (lssa): external, left as-is
    };

    logos-execution-zone-wallet-ui = {
      url = "github:logos-blockchain/logos-execution-zone-wallet-ui";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-execution-zone-module.follows = "logos-execution-zone-module";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-design-system.follows = "logos-design-system";
      inputs.nix-bundle-lgx.follows = "nix-bundle-lgx";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
    };

    # ── Modules: Other ────────────────────────────────────────────────────────

    logos-libp2p-module = {
      url = "github:logos-co/logos-libp2p-module";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-module-builder.follows = "logos-module-builder";
      # libp2p: external dep (vacp2p org), left as-is
    };

    logos-webview-app = {
      url = "github:logos-co/logos-webview-app";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    counter_qml = {
      url = "github:logos-co/counter_qml";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    counter = {
      url = "github:logos-co/counter";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    # ── UI ────────────────────────────────────────────────────────────────────

    logos-design-system = {
      url = "github:logos-co/logos-design-system";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };

    # ── SDKs ──────────────────────────────────────────────────────────────────

    logos-js-sdk = {
      url = "github:logos-co/logos-js-sdk";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-capability-module.follows = "logos-capability-module";
    };

    logos-nim-sdk = {
      url = "github:logos-co/logos-nim-sdk";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-liblogos.follows = "logos-liblogos";
    };

    logos-rust-sdk = {
      url = "github:logos-co/logos-rust-sdk";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Other ─────────────────────────────────────────────────────────────────

    logos-modules = {
      url = "github:logos-co/logos-modules";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-package.follows = "logos-package";
    };

    logos-module-viewer = {
      url = "github:logos-co/logos-module-viewer";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
      inputs.logos-capability-module.follows = "logos-capability-module";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
    };

    # ── Testing ──────────────────────────────────────────────────────────────

    logos-test-modules = {
      url = "github:logos-co/logos-test-modules";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-module-builder.follows = "logos-module-builder";
      inputs.logos-liblogos.follows = "logos-liblogos";
      inputs.logos-logoscore-cli.follows = "logos-logoscore-cli";
      inputs.logos-package-manager.follows = "logos-package-manager-module";
      inputs.nix-bundle-lgx.follows = "nix-bundle-lgx";
    };

    # Repos with no flake.nix (submodules only, not flake inputs):
    #   logos-docs, logos-website, logos-tutorial,
    #   logos-template-module, node-configs
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = fn: nixpkgs.lib.genAttrs systems fn;

      # Every logos flake input (for iteration).  Repos without a flake.nix
      # are NOT listed here — they are submodules only.
      repoInputNames = [
        # Foundation
        "logos-cpp-sdk" "logos-module" "logos-liblogos" "logos-logoscore-cli"
        "logos-capability-module" "logos-package" "logos-module-builder"
        # Packaging / Bundling
        "nix-bundle-dir" "nix-bundle-lgx"
        # App
        "logos-basecamp" "logos-standalone-app"
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
        # Blockchain / Execution zone (LEX)
        "logos-blockchain-module" "logos-blockchain-ui" "logos-execution-zone-module" "logos-execution-zone-wallet-ui"
        # Other modules
        "logos-libp2p-module" "logos-webview-app"
        "counter_qml" "counter"
        # UI
        "logos-design-system"
        # SDKs
        "logos-js-sdk" "logos-nim-sdk" "logos-rust-sdk"
        # Testing
        "logos-test-modules"
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
      # nix build .#logos-cpp-sdk          → default package
      # nix build .#logos-basecamp          → default package
      # nix build .#logos-basecamp--portable → non-default output
      # nix build .#logos-liblogos--portable
      # nix bundle --bundler .#nix-bundle-lgx .#logos-chat-module--lib
      # All repo package outputs are exposed: default as the repo name,
      # non-default as <repo>--<output>.
      packages = forAllSystems (system:
        let
          # Collect all package outputs from all repos.
          # Each repo's packages are forwarded lazily — the value is not
          # evaluated until someone actually builds it, so broken store
          # paths or missing files won't cause errors at evaluation time.
          allPkgs = builtins.foldl' (acc: name:
            let
              repoPkgs = (inputs.${name}.packages.${system} or {});
              outNames = builtins.attrNames repoPkgs;
            in
            acc // builtins.listToAttrs (map (outName:
              let
                attrName = if outName == "default" then name else "${name}--${outName}";
              in
              { name = attrName; value = repoPkgs.${outName}; }
            ) outNames)
          ) {} repoInputNames;
        in allPkgs
      );

      # ── Apps ──────────────────────────────────────────────────────────────
      # nix run .#logos-standalone-app -- --plugin ./result/lib/
      # Forwards apps outputs from all repos. Default app exposed as repo name,
      # non-default as <repo>--<output>.
      apps = forAllSystems (system:
        builtins.foldl' (acc: name:
          let
            repoApps = (inputs.${name}.apps.${system} or {});
            outNames = builtins.attrNames repoApps;
          in
          acc // builtins.listToAttrs (map (outName:
            let
              attrName = if outName == "default" then name else "${name}--${outName}";
            in
            { name = attrName; value = repoApps.${outName}; }
          ) outNames)
        ) {} repoInputNames
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
          # Always delegates to the live scripts/ws in the workspace,
          # without needing to rebuild the devshell. Falls back to the
          # flake directory if LOGOS_WORKSPACE_ROOT is not set.
          wsScript = pkgs.writeShellScriptBin "ws" ''
            exec "''${LOGOS_WORKSPACE_ROOT:-${builtins.toString ./.}}/scripts/ws" "$@"
          '';
        in {
          default = import ./nix/devshell.nix { inherit pkgs wsScript; };
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

      # ── Bundlers ──────────────────────────────────────────────────────────
      # Forwards nix-bundle-lgx bundlers so scripts can use "$WORKSPACE_ROOT"
      # as the --bundler reference. 
      bundlers = forAllSystems (system:
        inputs.nix-bundle-lgx.bundlers.${system}
      );

      # ── Lib (for programmatic use) ────────────────────────────────────────
      lib = {
        inherit repoInputNames inputToDir;
        # Dependency graph: input name → { deps = [ ... ]; hasTests = bool; }
        depGraph = import ./nix/dep-graph.nix;
      };
    };
}
