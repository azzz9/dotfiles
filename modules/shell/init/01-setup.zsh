# Keep completion widgets in Emacs mode even when EDITOR or VISUAL is vi-like.
bindkey -e

# Completion cache: writable location, skip the security audit.
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$HOST-${ZSH_VERSION}"
ZSH_DISABLE_COMPFIX=true
DISABLE_AUTO_UPDATE=true
mkdir -p "${ZSH_COMPDUMP:h}"

# zsh-autocomplete runs its async completion in a PTY, which needs the
# `interactive_comments` option: without it the `#` in the plugin's
# commented-out $(...) line parses as a command and its braces abort command
# substitution, so no async candidates render.
setopt interactive_comments

zstyle ':autocomplete:*' enabled yes
# Its key-bindings module requires terminfo[kcbt]; plugin init aborts on
# terminals that do not expose that key.
zstyle ':autocomplete:key-bindings' enabled no

# $fg/$bg availability and a dynamic prompt; ls/diff colors come from the
# shellAliases in modules/shell.nix instead of subprocess calls.
autoload -U colors && colors
setopt prompt_subst

# zsh core renders pasted text reverse-video (zle_highlight[paste]=standout).
# Neutralize only that context; the other defaults stay as they are.
zle_highlight=(region:standout special:standout suffix:bold isearch:underline paste:none)
