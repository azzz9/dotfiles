{ ... }:
{
  programs.tmux = {
    enable = true;
    extraConfig = ''
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      set -g mouse on

      setw -g mode-keys vi
      set -g status-keys vi

      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

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
      set -ga terminal-features 'tmux-256color:RGB'

      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'egel/tmux-gruvbox'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-continuum'
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '5'
      set -g @tmux-gruvbox 'dark'
      run '~/.tmux/plugins/tpm/tpm'
    '';
  };
}
