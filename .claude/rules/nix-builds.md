---
paths:
  - "**/flake.nix"
  - "**/flake.lock"
  - "nix/**"
---

# Nix Build Rules

- All repos build via nix flakes. Use `ws build <repo>` instead of raw `nix build`.
- The workspace nixpkgs follows `logos-cpp-sdk/nixpkgs`. Never add a separate nixpkgs pin.
- When editing a repo's flake.nix inputs, run `ws sync-graph` afterward to update dep-graph.nix.
- New files must be `git add`-ed before nix can see them (flakes only see tracked files).
- Use `ws build <repo> --auto-local` to test changes with local dependency overrides.
- After changing flake inputs or follows, run `ws update <repo>` to refresh flake.lock.
