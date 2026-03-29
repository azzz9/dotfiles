{ pkgs, ... }:
let
  tmuxClipboardCopy = pkgs.writeShellScriptBin "tmux-clipboard-copy" ''
    #!/usr/bin/env bash
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
in
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      gruvbox
      {
        plugin = resurrect;
        extraConfig = ''
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
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      set -g mouse on

      set -g history-limit 100000
      set -g renumber-windows on
      set -g base-index 1
      setw -g pane-base-index 1

      setw -g mode-keys vi
      set -g status-keys vi
      set -g set-clipboard on
      set -g xterm-keys on
      set -g extended-keys on

      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${tmuxClipboardCopy}/bin/tmux-clipboard-copy"
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"
      bind C display-popup -E -w 95% -h 95% -d "#{pane_current_path}" "zsh -lc 'codex --no-alt-screen'"
      bind G display-popup -E -w 95% -h 95% -d "#{pane_current_path}" "zsh -lc 'gh copilot'"

      unbind '"'
      unbind %
      bind / split-window -h
      bind - split-window -v

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

      set -g pane-border-status top
      if-shell -b "tmux list-options -g | grep -q '^pane-border-format'" \
        "set -g pane-border-format ' #{pane_index} #{pane_current_command} '"
      if-shell -b "tmux list-options -g | grep -q '^pane-active-border-format'" \
        "set -g pane-active-border-format ' #{pane_index}* #{pane_current_command} '"

      # Let gruvbox theme control window status formats

      set -g status-interval 2

      set -sg escape-time 10
      set -g default-terminal "tmux-256color"
      set -g focus-events on
      set -ga terminal-features 'xterm-256color:RGB'
      set -ga terminal-features 'xterm-256color:extkeys'
      set -ga terminal-features 'tmux-256color:RGB'
      set -ga terminal-features 'tmux-256color:extkeys'

      set -g @tmux-gruvbox 'dark'
    '';
  };
}
