---
name: merge-chain
description: Activate when the user wants to merge a chain of dependent cross-repo PRs, orchestrate multi-repo PR merges, or says "merge chain", "merge PRs", "/merge-chain". Expects a logos-workspace PR as input.
---

# Merge Chain — Multi-Repo PR Merge Orchestrator

Orchestrates merging a chain of dependent PRs across multiple repos in the Logos workspace. The user provides a workspace PR; this skill analyzes it, builds a merge plan, and executes it step by step.

## Phase 1: Analyze the workspace PR

1. **Fetch the workspace PR details:**
   ```bash
   gh pr view <NUMBER> --repo logos-co/logos-workspace --json headRefName,baseRefName,state,title,body,url
   ```

2. **Determine which submodules and flake inputs changed** by diffing the PR:
   ```bash
   gh pr diff <NUMBER> --repo logos-co/logos-workspace
   ```
   Look for:
   - Submodule pointer changes (lines like `Subproject commit <hash>` under `repos/<name>`)
   - `flake.lock` changes (input URL/hash updates)

3. **For each changed submodule, find the corresponding upstream PR.** Check for open or recently merged PRs on the same branch name:
   ```bash
   gh pr list --repo logos-co/<repo-name> --state all --json number,title,headRefName,state,mergedAt --limit 20
   ```
   Match by branch name (usually the same feature branch across repos). If a PR is already merged, note it — it can be skipped during execution.

4. **For each upstream repo with a PR, check for temporary `?ref=` branch references** in its flake.nix. These are added during development to point to unmerged upstream feature branches:
   ```bash
   grep '?ref=' repos/<repo-name>/flake.nix
   ```
   IMPORTANT: First fetch the PR branch to check the version of flake.nix on that branch, not just what's on disk:
   ```bash
   cd repos/<repo-name>
   git fetch origin <pr-branch>
   git show origin/<pr-branch>:flake.nix | grep '?ref='
   ```

## Phase 2: Build the merge plan

1. **Read the dependency graph** from `nix/dep-graph.nix`. This maps each repo's flake input name to its deps list.

2. **Compute topological merge order.** From the repos that have PRs to merge, sort them so that dependencies come before dependents. Repos with no deps on other changed repos go first. The workspace PR is always last.

3. **Map between repo directory names and flake input names.** They usually match, but check the workspace `flake.nix` inputs section to confirm. The `ws` script's repo registry (in `scripts/ws`, the `REPOS` array) also has this mapping.

4. **Check for vendor submodules** in downstream repos. Some repos have `vendor/<dep>` git submodules (e.g., `logos-liblogos` has `vendor/logos-cpp-sdk`). These need updating alongside flake inputs:
   ```bash
   git -C repos/<repo-name> submodule status | grep <dep-name>
   ```

5. **Present the plan to the user.** Format it clearly:

   ```
   ## Merge Chain Plan

   Repos to merge (in dependency order):
     1. logos-cpp-sdk#20 — "title" [ready to merge]
     2. logos-liblogos#64 — "title" [depends on logos-cpp-sdk]
        - flake.nix has ?ref=feat/branch for logos-cpp-sdk (will revert)
        - vendor/logos-cpp-sdk submodule needs updating
     3. logos-workspace#6 — "title" [aggregator, last]

   Execution steps:
     1. Merge logos-co/logos-cpp-sdk#20
     2. On logos-liblogos branch <branch>:
        a. Revert ?ref= in flake.nix
        b. Update flake.lock: nix flake lock --update-input logos-cpp-sdk
        c. Update vendor/logos-cpp-sdk submodule
        d. Commit and push
     3. [Optional] Wait for logos-liblogos CI
     4. Merge logos-co/logos-liblogos#64
     5. On workspace branch <branch>:
        a. Update submodule pointers (repos/logos-cpp-sdk, repos/logos-liblogos)
        b. Update flake.lock
        c. Commit, rebase onto base branch, push
     6. Merge logos-co/logos-workspace#<N>

   Proceed?
   ```

   Wait for user confirmation before proceeding to Phase 3.

## Phase 3: Execute the plan

Execute each step, **asking for user confirmation before each merge and each push**. Use `gh` CLI for GitHub operations and `git` for local operations.

### For each upstream repo (in topological order):

**Step A: Merge the PR**

```bash
gh pr merge <NUMBER> --repo logos-co/<repo-name> --squash --delete-branch
```

Ask the user which merge strategy they prefer if not obvious (squash, merge commit, rebase). Default to squash.

After merging, note the merge commit hash on the target branch:
```bash
gh api repos/logos-co/<repo-name>/git/ref/heads/<base-branch> --jq '.object.sha'
```

**Step B: Fix up each downstream repo in the chain**

For each downstream repo that depends on the just-merged repo:

1. **Checkout the PR branch locally:**
   ```bash
   cd repos/<downstream-repo>
   git fetch origin
   git checkout <pr-branch>
   ```

2. **Revert `?ref=` in flake.nix** (if present). Edit flake.nix to change:
   ```
   url = "github:logos-co/<repo>?ref=<branch>";
   ```
   back to:
   ```
   url = "github:logos-co/<repo>";
   ```

3. **Update flake.lock** to pick up the newly merged commit:
   ```bash
   nix flake lock --update-input <input-name>
   ```
   Use the flake input name as declared in THAT repo's own flake.nix (not the workspace input name — they may differ).

4. **Update vendor submodule** (if it exists):
   ```bash
   # Check if vendor/<dep> exists
   if [ -d vendor/<dep> ]; then
     cd vendor/<dep>
     git fetch origin
     git checkout origin/<base-branch>
     cd ../..
     git add vendor/<dep>
   fi
   ```

5. **Commit and push:**
   ```bash
   git add flake.nix flake.lock
   git commit -m "update <dep> to merged main"
   git push origin <pr-branch>
   ```

6. **Optionally wait for CI** — ask the user:
   ```bash
   gh pr checks <NUMBER> --repo logos-co/<downstream-repo> --watch
   ```
   Or skip if the user wants to proceed immediately (the changes are mechanical).

Then merge this downstream PR and repeat for the next level.

### Final step: Update and merge the workspace PR

1. **Checkout the workspace PR branch:**
   ```bash
   git checkout <workspace-pr-branch>
   ```

2. **Update each submodule pointer** to the final merged commit:
   ```bash
   cd repos/<repo-name>
   git fetch origin
   git checkout origin/<main-branch>
   cd ../..
   ```

3. **Update the workspace flake.lock** using flake input names:
   ```bash
   nix flake update <input1> <input2> ...
   ```

4. **Stage and commit:**
   ```bash
   git add repos/<repo1> repos/<repo2> ... flake.lock
   git commit -m "update flake references after merging upstream PRs"
   ```

5. **Rebase onto base branch** to keep history clean, then push:
   ```bash
   git rebase <base-branch>
   git push origin <workspace-pr-branch> --force-with-lease
   ```
   Confirm with user before force-pushing.

6. **Merge the workspace PR:**
   ```bash
   gh pr merge <NUMBER> --repo logos-co/logos-workspace --squash --delete-branch
   ```

## Key reference

### Repo name to flake input name mapping

Usually identical. The workspace `flake.nix` inputs section is the source of truth. Exceptions are in the `inputToDirOverrides` map in flake.nix (e.g., `counter_qml`, `counter`).

### The `follows` mechanism

The workspace flake.nix uses `follows` so overriding one input propagates downstream. But each repo's own `flake.lock` must be independently correct for standalone CI builds. That's why we must update each repo's `flake.lock` after its upstream deps merge — the workspace `follows` don't help individual repo CI.

### Common `?ref=` pattern

During development, downstream repos add `?ref=<feature-branch>` to flake.nix inputs to build against unmerged upstream code. Example:
```nix
logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk?ref=feat/logos-instance-id";
```
This MUST be reverted to `"github:logos-co/logos-cpp-sdk"` before or during the merge chain. The skill handles this automatically.

### Detecting which repo default branch is `main` vs `master`

```bash
gh repo view logos-co/<repo-name> --json defaultBranchRef --jq '.defaultBranchRef.name'
```

### Error recovery

If any step fails (merge conflict, CI failure, permission denied):
- Stop immediately and report to the user
- Do NOT proceed with downstream merges
- State is recoverable: upstream merges are complete, downstream branches have at most a fixup commit that can be reverted

### After everything is merged

Return to the workspace master branch, update submodules, and run `ws update` for all repos that changed. This updates the workspace `flake.lock` to point to the latest commits on each repo's default branch, which is essential after merging upstream PRs.

```bash
git checkout master
git pull
git submodule update
ws update <repo1> <repo2> ...
```

The `ws update` arguments should be the flake input names of ALL repos that were merged in the chain, plus any repos whose flake.lock was updated as part of the fixup steps. For example, if logos-cpp-sdk and logos-liblogos were merged:
```bash
ws update logos-cpp-sdk logos-liblogos
```

If other repos were also affected (e.g., logos-test-modules had its flake.lock updated because it depends on logos-liblogos), include those too:
```bash
ws update logos-cpp-sdk logos-liblogos logos-test-modules
```

This step ensures the workspace flake.lock is fully in sync with all the newly merged upstream commits. Without it, the workspace would still reference the old (pre-merge) commit hashes.
