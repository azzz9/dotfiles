{ pkgs, ... }:
let
  # Tokyo Night palette (github.com/folke/tokyonight.nvim)
  # Used for pane-border, popup, message, and other non-status-line styling.
  tn = {
    bg          = "#1a1b26";
    bgDark      = "#16161e";
    bgHighlight = "#292e42";
    fg          = "#c0caf5";
    fgGutter    = "#3b4261";
    comment     = "#737aa2";
    blue        = "#7aa2f7";
    cyan        = "#7dcfff";
    magenta     = "#bb9af7";
    green       = "#9ece6a";
    yellow      = "#e0af68";
    orange      = "#ff9e64";
    red         = "#f7768e";
    purple      = "#9d7cd8";
  };

  tmuxClipboardCopy = pkgs.writeShellScriptBin "tmux-clipboard-copy" ''
    set -euo pipefail

    if command -v wl-copy >/dev/null 2>&1 && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      exec wl-copy
    fi

    if command -v xclip >/dev/null 2>&1 && [ -n "''${DISPLAY:-}" ]; then
      exec xclip -selection clipboard -in
    fi

    if command -v clip.exe >/dev/null 2>&1; then
      exec clip.exe
    fi

    if command -v pbcopy >/dev/null 2>&1; then
      exec pbcopy
    fi

    cat >/dev/null
  '';

  # tokyo-night-tmux uses bash associative arrays (declare -A) in
  # themes.sh / netspeed.sh, which require bash >= 4. macOS ships
  # /bin/bash 3.2, so patch every script shebang to the Nix bash 5.
  # Using an absolute store path avoids depending on runtime PATH
  # (which macOS tmux may not populate with Nix profile bins).
  tokyoNightTmux = pkgs.tmuxPlugins.tokyo-night-tmux.overrideAttrs (oa: {
    postInstall = (oa.postInstall or "") + ''
      for f in "$out/share/tmux-plugins/tokyo-night-tmux/tokyo-night.tmux" \
               "$out"/share/tmux-plugins/tokyo-night-tmux/src/*.sh; do
        substituteInPlace "$f" \
          --replace '#!/usr/bin/env bash' '#!${pkgs.bash}/bin/bash'
      done
    '';
  });
in
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = tokyoNightTmux;
        extraConfig = ''
          set -g @tokyo-night-tmux_theme "night"
          set -g @tokyo-night-tmux_show_datetime 1
          set -g @tokyo-night-tmux_date_format "%Y-%m-%d"
          set -g @tokyo-night-tmux_time_format "%H:%M"
          set -g @tokyo-night-tmux_show_netspeed 1
          set -g @tokyo-night-tmux_show_wbg 0
          set -g @tokyo-night-tmux_show_path 1
          set -g @tokyo-night-tmux_window_id_style "hide"
          set -g @tokyo-night-tmux_pane_id_style "hide"
          set -g @tokyo-night-tmux_zoom_id_style "hide"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-dir '~/.local/share/tmux/resurrect'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
    extraConfig = ''
      # === Key bindings ===
      unbind C-a
      unbind C-g
      unbind C-Space
      set -g prefix C-b
      bind C-b send-prefix

      set -g mouse on

      set -g history-limit 100000
      set -g renumber-windows on
      set -g base-index 1
      setw -g pane-base-index 1

      setw -g mode-keys vi
      set -g status-keys vi
      set -g set-clipboard on
      set -g extended-keys on

      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${tmuxClipboardCopy}/bin/tmux-clipboard-copy"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${tmuxClipboardCopy}/bin/tmux-clipboard-copy"
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"
      bind C display-popup -E -w 95% -h 95% -d "#{pane_current_path}" "zsh -lc 'codex --no-alt-screen'"
      bind G display-popup -E -w 95% -h 95% -d "#{pane_current_path}" "zsh -lc 'gh copilot'"

      unbind '"'
      unbind %
      bind / split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      bind -r h select-pane -L
      bind -r j select-pane -D
      bind -r k select-pane -U
      bind -r l select-pane -R

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R
      bind -n M-p choose-tree -Zw
      bind -n M-w choose-tree -Zw
      bind -n M-s choose-tree -Zs
      bind -n M-Left previous-window
      bind -n M-Right next-window
      bind -n M-Up switch-client -p
      bind -n M-Down switch-client -n

      # Reset: clear resurrect data + kill server (restart with `tmux`)
      bind X confirm-before -p "Reset all tmux sessions? (y/n)" "run-shell 'rm -rf ~/.local/share/tmux/resurrect/ && tmux kill-server'"

      set -g status-interval 2

      set -sg escape-time 10
      set -g default-terminal "tmux-256color"
      set -g focus-events on
      set -ga terminal-features 'xterm-256color:RGB'
      set -ga terminal-features 'xterm-256color:extkeys'
      set -ga terminal-features 'tmux-256color:RGB'
      set -ga terminal-features 'tmux-256color:extkeys'

      # === Theme: tokyo-night-tmux plugin handles status line & window tabs ===
      # Override: keep status bar at top (plugin default is bottom)
      set -g status-position top

      # Override window tab formats for clearer active/inactive distinction
      setw -g window-status-current-format "#[bg=${tn.blue},fg=${tn.bg},bold] #W #[bg=${tn.bg}]"
      setw -g window-status-format "#[fg=${tn.comment},dim] #W #[nodim]"
      setw -g window-status-separator ""

      # --- Pane borders (heavy lines) ---
      set -g pane-border-status top
      set -g pane-border-lines heavy
      set -g pane-border-style "fg=${tn.fgGutter}"
      set -g pane-border-format " #[fg=${tn.cyan}]#{pane_index}#[fg=${tn.fg}] #{pane_current_command} "
      set -g pane-border-indicators colour

      # --- Popup (rounded corners for codex / gh copilot) ---
      set -g popup-style "bg=${tn.bg},fg=${tn.fg}"
      set -g popup-border-style "fg=${tn.blue}"
      set -g popup-border-lines rounded

      # --- Copy mode ---
      setw -g mode-style "bg=${tn.bgHighlight},fg=${tn.fg}"

      # --- Message / command prompt ---
      set -g message-style "bg=${tn.blue},fg=${tn.bg},bold"
      set -g message-command-style "bg=${tn.blue},fg=${tn.bg},bold"

      # --- Display panes (prefix q) ---
      set -g display-panes-colour "${tn.fg}"
      set -g display-panes-active-colour "${tn.blue}"

      # --- Clock mode ---
      set -g clock-mode-colour "${tn.cyan}"
      set -g clock-mode-style 24
    '';
  };
}
