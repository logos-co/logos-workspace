# Dev shell configuration for the Logos workspace.
# Provides a modern, batteries-included shell environment.
#
# Used by: flake.nix devShells.default
{ pkgs, wsScript }:

let
  # Starship prompt config
  starshipConfig = pkgs.writeText "starship.toml" ''
    format = """$directory$git_branch$git_status$nix_shell$character"""

    [character]
    success_symbol = "[λ](bold green)"
    error_symbol = "[λ](bold red)"

    [directory]
    truncation_length = 3
    truncate_to_repo = true
    style = "bold cyan"

    [git_branch]
    format = " [$branch]($style)"
    style = "bold purple"

    [git_status]
    format = "[$all_status$ahead_behind]($style) "
    style = "bold yellow"

    [nix_shell]
    format = "[$symbol]($style)"
    symbol = " ❄"
    style = "bold blue"
  '';

  # Delta (git pager) config
  deltaConfig = pkgs.writeText "delta-gitconfig" ''
    [core]
        pager = delta
    [interactive]
        diffFilter = delta --color-only
    [delta]
        navigate = true
        side-by-side = true
        line-numbers = true
        hyperlinks = true
    [merge]
        conflictstyle = diff3
  '';

  # Tmux config
  tmuxConfig = pkgs.writeText "tmux.conf" ''
    # ── General ──────────────────────────────────────────────────────
    set -g default-shell "${pkgs.zsh}/bin/zsh"
    set -g default-command "${pkgs.zsh}/bin/zsh"
    set -g default-terminal "tmux-256color"
    set -ag terminal-overrides ",xterm-256color:RGB"
    set -g mouse on
    set -g history-limit 50000
    set -g base-index 1
    setw -g pane-base-index 1
    set -g renumber-windows on
    set -g set-clipboard on
    set -sg escape-time 0
    set -g focus-events on

    # ── Prefix ───────────────────────────────────────────────────────
    unbind C-b
    set -g prefix C-a
    bind C-a send-prefix

    # ── Splits ───────────────────────────────────────────────────────
    bind | split-window -h -c "#{pane_current_path}"
    bind - split-window -v -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"
    unbind '"'
    unbind %

    # ── Navigation (vim-style) ───────────────────────────────────────
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # ── Resize (hold prefix + arrow) ─────────────────────────────────
    bind -r H resize-pane -L 5
    bind -r J resize-pane -D 5
    bind -r K resize-pane -U 5
    bind -r L resize-pane -R 5

    # ── Copy mode (vi-style) ─────────────────────────────────────────
    setw -g mode-keys vi
    bind v copy-mode
    bind -T copy-mode-vi v send -X begin-selection
    bind -T copy-mode-vi y send -X copy-selection-and-cancel

    # ── Status bar ───────────────────────────────────────────────────
    set -g status-position top
    set -g status-style "bg=default,fg=white"
    set -g status-left-length 40
    set -g status-right-length 80

    set -g status-left "#[fg=blue,bold]  #S #[fg=brightblack]│ "
    set -g status-right "#[fg=brightblack]│ #[fg=cyan]󰃭 %H:%M"

    # Window tabs
    set -g window-status-format "#[fg=brightblack] #I:#W "
    set -g window-status-current-format "#[fg=cyan,bold] #I:#W "
    set -g window-status-separator ""

    # Pane borders
    set -g pane-border-style "fg=brightblack"
    set -g pane-active-border-style "fg=cyan"

    # ── Quick reload ─────────────────────────────────────────────────
    bind r source-file ~/.tmux.conf \; display "Config reloaded"
  '';

  # Zsh config
  zshrc = pkgs.writeText "logos-zshrc" ''
    # ── Zsh options ────────────────────────────────────────────────────
    setopt AUTO_CD
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_SPACE
    setopt SHARE_HISTORY
    setopt EXTENDED_HISTORY
    setopt INC_APPEND_HISTORY
    HISTFILE=''${HOME}/.zsh_history
    HISTSIZE=50000
    SAVEHIST=50000

    # ── Completion ─────────────────────────────────────────────────────
    autoload -Uz compinit && compinit
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
    zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
    zstyle ':completion:*:descriptions' format '%F{cyan}-- %d --%f'
    zstyle ':completion:*' group-name '''

    # ── ws tab completion ─────────────────────────────────────────────
    _ws() {
      local -a commands
      commands=(
        'init:Clone all submodules'
        'list:List all repos and their status'
        'build:Build a repo via nix'
        'run:Build and run a repo'
        'develop:Enter a nix devShell'
        'test:Run checks/tests'
        'status:Git status across all repos'
        'dirty:Show dirty repos and what they affect'
        'graph:Show dependency graph'
        'override-inputs:Show nix override flags'
        'update:Update flake.lock inputs'
        'loc:Count lines of code'
        'watch:Auto-run commands on file changes'
        'foreach:Run a command in every repo'
        'worktree:Manage worktrees'
        'sync-graph:Regenerate dep-graph.nix'
        'help:Show help'
      )
      local -a repos
      repos=($(ls "$LOGOS_WORKSPACE_ROOT/repos/" 2>/dev/null))

      if (( CURRENT == 2 )); then
        _describe 'command' commands
      elif (( CURRENT == 3 )); then
        case "''${words[2]}" in
          build|run|develop|test|graph|update|override-inputs|loc)
            _describe 'repo' repos
            ;;
          watch)
            local -a watch_cmds
            watch_cmds=('test:Re-run tests on change' 'build:Re-build on change' 'run:Run command on change')
            _describe 'subcommand' watch_cmds
            ;;
          worktree)
            local -a wt_cmds
            wt_cmds=('add:Create a worktree' 'list:List worktrees' 'remove:Remove a worktree')
            _describe 'subcommand' wt_cmds
            ;;
        esac
      elif (( CURRENT >= 4 )); then
        case "''${words[2]}" in
          build|run|develop|override-inputs)
            local -a opts
            opts=('--auto-local' '--local' '--fresh')
            _describe 'option' opts
            ;;
          test)
            local -a opts
            opts=('--all' '--type')
            _describe 'option' opts
            ;;
          loc)
            local -a opts
            opts=('--all' '--no-nix' '--code-only')
            _describe 'option' opts
            ;;
          watch)
            _describe 'repo' repos
            ;;
        esac
      fi
    }
    compdef _ws ws

    # ── Plugins ────────────────────────────────────────────────────────
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh

    # History substring search keybindings (up/down arrows)
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down

    # Autosuggestions — accept with right arrow or end key
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"

    # ── Aliases ────────────────────────────────────────────────────────
    # ls wrapper — translates common ls flags to eza equivalents
    ls() {
      local args=()
      for arg in "$@"; do
        case "$arg" in
          -ltra|-lart|-latr) args+=(--long --all --sort=modified --reverse) ;;
          -ltr|-lrt)         args+=(--long --sort=modified --reverse) ;;
          -la|-al)           args+=(--long --all) ;;
          -lt|-tl)           args+=(--long --sort=modified) ;;
          *)                 args+=("$arg") ;;
        esac
      done
      eza --icons=auto --group-directories-first "''${args[@]}"
    }
    alias ll='eza --icons=auto --group-directories-first -la'
    alias lt='eza --icons=auto --tree --level=3'
    alias la='eza --icons=auto --group-directories-first -a'
    alias cat='bat --paging=never --style=plain'
    alias less='bat --paging=always'
    alias vim='nvim'
    alias vi='nvim'
    alias cd='z'

    # ws shortcuts
    alias wss='ws status'
    alias wsb='ws build'
    alias wst='ws test'
    alias wsd='ws dirty'
    alias wsg='ws graph'

    # git shortcuts
    alias gst='git status'
    alias gs='git status -s'
    alias ga='git add'
    alias gc='git commit'
    alias gcm='git commit -m'
    alias gd='git diff'
    alias gds='git diff --staged'
    alias gl='git log --oneline --graph --decorate -20'
    alias glog='git log --graph --decorate --oneline --all'
    alias gp='git pull'
    alias gps='git push'
    alias gco='git checkout'
    alias gb='git branch'
    alias gcp='git cherry-pick'
    alias grb='git rebase'
    alias lg='lazygit'

    # ── Environment ────────────────────────────────────────────────────
    export EDITOR=nvim
    export VISUAL=nvim
    export PAGER='less -R'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"

    # Git — use delta as pager via env vars only (no global config changes)
    export GIT_PAGER='delta --paging=always'
    export DELTA_PAGER='less -R'
    export GIT_CONFIG_COUNT=4
    export GIT_CONFIG_KEY_0="delta.navigate"
    export GIT_CONFIG_VALUE_0="true"
    export GIT_CONFIG_KEY_1="delta.side-by-side"
    export GIT_CONFIG_VALUE_1="true"
    export GIT_CONFIG_KEY_2="delta.line-numbers"
    export GIT_CONFIG_VALUE_2="true"
    export GIT_CONFIG_KEY_3="diff.submodule"
    export GIT_CONFIG_VALUE_3="diff"

    # Starship prompt
    export STARSHIP_CONFIG="${starshipConfig}"
    eval "$(starship init zsh)"

    # fzf — fuzzy finder + keybindings (Ctrl-T, Ctrl-R, Alt-C)
    source <(fzf --zsh)
    export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --margin=0,1'
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

    # zoxide
    eval "$(zoxide init zsh)"


    # ── Workspace ──────────────────────────────────────────────────────
    export LOGOS_WORKSPACE_ROOT="''${LOGOS_WORKSPACE_ROOT:-$(pwd)}"
    export PATH="$LOGOS_WORKSPACE_ROOT/scripts:$PATH"

    # ── Welcome ────────────────────────────────────────────────────────
    if [[ -z "$LOGOS_WELCOMED" ]]; then
      export LOGOS_WELCOMED=1
      echo ""
      echo -e "\033[1;36m  Logos Workspace\033[0m"
      echo -e "\033[0;90m  ─────────────────────────────────────────────────────\033[0m"
      echo -e "  \033[1mws help\033[0m     Commands    \033[0;90m│\033[0m  \033[1mCtrl-A |\033[0m  Split horizontal"
      echo -e "  \033[1mws status\033[0m   Repo status  \033[0;90m│\033[0m  \033[1mCtrl-A -\033[0m  Split vertical"
      echo -e "  \033[1mws dirty\033[0m    Impact       \033[0;90m│\033[0m  \033[1mCtrl-A c\033[0m  New tab"
      echo -e "  \033[1mws graph\033[0m    Dep graph    \033[0;90m│\033[0m  \033[1mCtrl-A d\033[0m  Detach"
      echo -e "\033[0;90m  ─────────────────────────────────────────────────────\033[0m"
      echo -e "  \033[0;90mCtrl-R: history search  Ctrl-T: file search  Tab: complete\033[0m"
      echo ""
    fi
  '';

  # Wrapper script that launches zsh inside tmux
  enterShell = pkgs.writeShellScriptBin "logos-shell" ''
    export ZDOTDIR=$(mktemp -d)
    cp ${zshrc} "$ZDOTDIR/.zshrc"
    # Suppress macOS /etc/zshrc "locale: command not found" error
    echo 'locale() { :; }' > "$ZDOTDIR/.zshenv"

    # Launch tmux with zsh, or attach if session exists
    if command -v tmux &>/dev/null; then
      if tmux has-session -t logos 2>/dev/null; then
        exec tmux attach -t logos
      else
        tmux -f ${tmuxConfig} new-session -d -s logos -n workspace
        tmux set-environment -t logos ZDOTDIR "$ZDOTDIR"
        tmux set-environment -t logos STARSHIP_CONFIG "${starshipConfig}"
        tmux set-environment -t logos GIT_PAGER "delta --paging=always"
        tmux set-environment -t logos DELTA_PAGER "less -R"
        tmux set-environment -t logos LOGOS_WORKSPACE_ROOT "''${LOGOS_WORKSPACE_ROOT:-$(pwd)}"
        tmux set-environment -t logos PATH "$PATH"
        exec tmux attach -t logos
      fi
    else
      exec ${pkgs.zsh}/bin/zsh
    fi
  '';

in pkgs.mkShell {
  name = "logos-workspace";

  packages = with pkgs; [
    # ── Core ──────────────────────────────────────────────────────────
    git
    openssh
    jq
    nix
    wsScript

    # ── Shell ─────────────────────────────────────────────────────────
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    starship              # cross-shell prompt
    tmux                  # terminal multiplexer

    # ── Fuzzy & Navigation ────────────────────────────────────────────
    fzf                   # fuzzy finder (Ctrl-R, Ctrl-T)
    fd                    # fast find (used by fzf)
    zoxide                # smart cd

    # ── Modern CLI replacements ───────────────────────────────────────
    eza                   # modern ls
    bat                   # modern cat
    ripgrep               # modern grep
    delta                 # modern diff / git pager
    htop                  # modern top
    dust                  # modern du
    duf                   # modern df
    procs                 # modern ps

    # ── Git ───────────────────────────────────────────────────────────
    lazygit               # interactive git TUI

    # ── Code analysis & docs ─────────────────────────────────────────
    tokei                 # lines of code counter
    glow                  # markdown renderer

    # ── File watching ────────────────────────────────────────────────
    watchexec             # run commands on file changes

    # ── Editor ────────────────────────────────────────────────────────
    neovim

    # ── Build tools ───────────────────────────────────────────────────
    cmake
    ninja
    pkg-config
  ];

  shellHook = ''
    exec ${enterShell}/bin/logos-shell
  '';
}
