---
name: add-repo
description: Activate when adding a new git repo/submodule to the workspace, registering a repo in flake.nix or scripts/ws, promoting a non-flake repo to a flake repo, or the user says "add repo", "register repo", "new repo".
---

# Add Repo to Workspace

Registers a new (or existing) repo in all the workspace configuration files. There are two cases: **non-flake repos** (no `flake.nix` in the repo) and **flake repos** (has a `flake.nix`).

## Step 1: Determine repo state

Check what already exists:

```bash
# Does the submodule exist?
ls repos/<repo-name>/

# Is it in .gitmodules?
grep <repo-name> .gitmodules

# Does the repo have a flake.nix?
ls repos/<repo-name>/flake.nix

# Is it already in the workspace flake.nix?
grep <repo-name> flake.nix

# Is it already in scripts/ws REPOS array?
grep <repo-name> scripts/ws
```

## Step 2: Add git submodule (if not already done)

```bash
git submodule add git@github.com:logos-co/<repo-name>.git repos/<repo-name>
```

This updates `.gitmodules` and clones the repo into `repos/`.

## Step 3a: Register a NON-FLAKE repo (no flake.nix)

If the repo has no `flake.nix`, register it as a non-flake submodule:

### `scripts/ws` — add to REPOS array (non-flake section)

Add to the `# Non-flake repos (submodules only)` section:
```bash
"|<repo-name>|https://github.com/logos-co/<repo-name>.git|no"
```

Note: the first field (input_name) is empty for non-flake repos.

### `flake.nix` — add to non-flake comment

Add the repo name to the comment block near the end of the inputs section:
```nix
# Repos with no flake.nix (submodules only, not flake inputs):
#   ..., <repo-name>, ...
```

**Done.** No `dep-graph.nix` or `repoInputNames` entry needed for non-flake repos.

## Step 3b: Register a FLAKE repo (has flake.nix)

If the repo has a `flake.nix`, do all of the following:

### Read the repo's flake.nix to determine dependencies

```bash
cat repos/<repo-name>/flake.nix
```

Look at the `inputs` section to identify which workspace repos it depends on (logos-nix, logos-cpp-sdk, logos-liblogos, etc.) and what input names it uses.

### `flake.nix` — add input entry

Add an input block in the appropriate section (Foundation, Modules, SDKs, Other, etc.). Each workspace dependency needs a `follows` declaration so the workspace can override it:

```nix
<repo-name> = {
  url = "github:logos-co/<repo-name>";
  inputs.logos-nix.follows = "logos-nix";
  inputs.nixpkgs.follows = "nixpkgs";
  # Add follows for each workspace dep the repo uses:
  inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
  inputs.logos-liblogos.follows = "logos-liblogos";
  # etc.
};
```

**IMPORTANT mapping rules for `follows`:**
- The left side of `follows` is the input name **as declared in the repo's own flake.nix**
- The right side is the **workspace flake input name**
- These usually match, but not always (e.g., a repo may call its input `logos-core` while the workspace calls it `logos-cpp-sdk`)
- Check `inputToDirOverrides` in flake.nix for existing name mismatches
- External deps (not in workspace) should NOT get follows — leave them as-is with a comment

### `flake.nix` — add to `repoInputNames` array

Add `"<repo-name>"` to the `repoInputNames` list in the appropriate category section. This array controls which repos get their packages/checks exposed through the workspace.

### `scripts/ws` — add to REPOS array (flake section)

Add to the appropriate category section:
```bash
"<repo-name>|<repo-name>|https://github.com/logos-co/<repo-name>.git|yes"
```

Format: `"input_name|directory_name|git_url|has_flake"`
- `input_name` must match the flake.nix input name exactly
- `directory_name` is the submodule directory under `repos/`
- These usually match but not always

If the repo belongs in a group, also update the `REPO_GROUPS` array.

### `nix/dep-graph.nix` — run sync-graph

This file is **auto-generated**. Never edit it manually. Run:

```bash
ws sync-graph
```

This reads every repo's flake.nix, extracts its deps, and regenerates `dep-graph.nix`. It also detects whether the repo has tests (`hasTests`).

**If `ws sync-graph` fails** (e.g., because the repo's flake.nix references inputs not yet in the workspace), you may need to commit the flake.nix changes first, or manually add a temporary entry to dep-graph.nix matching the pattern:
```nix
<repo-name> = { deps = [ "dep1" "dep2" ]; hasTests = false; };
```

## Step 4: Promoting a non-flake repo to flake

When a repo that was previously registered as non-flake gets a `flake.nix`:

1. **Remove** from non-flake section in `scripts/ws` (the `"|<name>|...|no"` line)
2. **Remove** from non-flake comment in `flake.nix`
3. **Add** as a flake repo following Step 3b above

## Checklist

For a flake repo, verify all of these are done:

- [ ] `.gitmodules` — submodule registered
- [ ] `flake.nix` inputs — input block with correct `follows`
- [ ] `flake.nix` `repoInputNames` — listed in correct category
- [ ] `scripts/ws` REPOS — entry with `has_flake=yes`
- [ ] `scripts/ws` REPO_GROUPS — added to relevant group (if applicable)
- [ ] `nix/dep-graph.nix` — regenerated via `ws sync-graph`
- [ ] `flake.nix` non-flake comment — NOT listed there (remove if upgrading)

For a non-flake repo:

- [ ] `.gitmodules` — submodule registered
- [ ] `scripts/ws` REPOS — entry with `has_flake=no` and empty input_name
- [ ] `flake.nix` non-flake comment — listed there

## GitHub org variations

Most repos are under `logos-co`. Some are under other orgs:
- `logos-blockchain` — blockchain/LEX repos (logos-blockchain-module, logos-execution-zone-module, etc.)

Adjust the GitHub URL accordingly.
