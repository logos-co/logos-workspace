# Dependency graph: flake input name → list of workspace input names it depends on.
# Only logos-co dependencies are tracked (external deps like go-wallet-sdk are omitted).
# Used by the ws CLI for --auto-local propagation and `ws graph`.
{
  # Foundation
  logos-cpp-sdk              = [];
  logos-module               = [ "logos-cpp-sdk" ];
  logos-liblogos             = [ "logos-cpp-sdk" "logos-capability-module" "logos-module" ];
  logos-capability-module    = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-package              = [ "logos-liblogos" ];
  logos-module-builder       = [ "logos-cpp-sdk" "logos-liblogos" ];

  # App
  logos-app-poc              = [
    "logos-cpp-sdk" "logos-liblogos" "logos-capability-module" "logos-package"
    "logos-package-manager-module" "logos-package-manager-ui" "logos-webview-app"
    "logos-design-system" "counter_qml" "counter"
  ];

  # Accounts
  logos-accounts-module      = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-accounts-ui          = [
    "logos-cpp-sdk" "logos-liblogos" "logos-accounts-module"
    "logos-capability-module" "logos-package-manager-module"
  ];

  # Chat & Messaging
  logos-chat-module          = [ "logos-cpp-sdk" "logos-liblogos" "logos-waku-module" ];
  logos-chat-legacy-module   = [ "logos-cpp-sdk" "logos-liblogos" "logos-waku-module" ];
  logos-chat-tui             = [
    "logos-liblogos" "logos-chat-module" "logos-waku-module"
    "logos-capability-module" "logos-rust-sdk"
  ];
  logos-chat-ui              = [
    "logos-cpp-sdk" "logos-liblogos" "logos-chat-legacy-module"
    "logos-waku-module" "logos-capability-module"
  ];
  logos-chatsdk-module       = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-chatsdk-ui           = [
    "logos-cpp-sdk" "logos-liblogos" "logos-chatsdk-module" "logos-capability-module"
  ];
  logos-irc-module           = [
    "logos-cpp-sdk" "logos-liblogos" "logos-chat-legacy-module"
    "logos-waku-module" "logos-capability-module"
  ];

  # Waku
  logos-waku-module          = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-waku-ui              = [
    "logos-cpp-sdk" "logos-liblogos" "logos-waku-module" "logos-capability-module"
  ];

  # Package Manager
  logos-package-manager-module = [ "logos-cpp-sdk" "logos-liblogos" "logos-package" ];
  logos-package-manager-ui   = [
    "logos-cpp-sdk" "logos-liblogos" "logos-package-manager-module"
    "logos-capability-module"
  ];

  # Storage
  logos-storage-module       = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-storage-ui           = [
    "logos-cpp-sdk" "logos-liblogos" "logos-storage-module"
    "logos-capability-module" "logos-design-system"
  ];

  # Wallet
  logos-wallet-module        = [ "logos-cpp-sdk" "logos-liblogos" ];
  logos-wallet-ui            = [
    "logos-cpp-sdk" "logos-liblogos" "logos-wallet-module" "logos-capability-module"
  ];

  # Other modules
  logos-libp2p-module        = [ "logos-module-builder" ];
  logos-simple-module        = [];
  logos-webview-app          = [ "logos-cpp-sdk" "logos-liblogos" ];
  counter_qml                = [ "logos-cpp-sdk" ];
  counter                    = [ "logos-cpp-sdk" ];

  # UI
  logos-design-system        = [];

  # SDKs
  logos-js-sdk               = [ "logos-liblogos" "logos-capability-module" ];
  logos-nim-sdk              = [ "logos-liblogos" ];
  logos-rust-sdk             = [];

  # Other
  logos-modules              = [ "logos-package" ];
  logos-module-viewer        = [
    "logos-liblogos" "logos-cpp-sdk" "logos-capability-module"
    "logos-package-manager-module"
  ];
}
