# Completion cache: writable location, skip security audit.
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$HOST-${ZSH_VERSION}"
ZSH_DISABLE_COMPFIX=true
DISABLE_AUTO_UPDATE=true
mkdir -p "${ZSH_COMPDUMP:h}"

# zsh-autocomplete runs its async list-choices completion inside a
# PTY (interactive mode).  In interactive zsh, `#` is NOT a comment
# by default — it requires the `interactive_comments` option.  The
# upstream compadd wrapper contains a commented-out line with braces
# inside a $(...) block; without this option zsh parses the `#` as
# a command and the braces cause "parse error in command substitution",
# which prevents async candidates from rendering at all.
setopt interactive_comments

zstyle ':autocomplete:*' enabled yes
# zsh-autocomplete's key-bindings module assumes terminfo[kcbt]
# exists. Some terminals do not expose it, which aborts plugin init
# before the completion widgets are installed.
zstyle ':autocomplete:key-bindings' enabled no

# --- Appearance: replaces OMZ theme-and-appearance.zsh ---
# No subprocess calls — ls/diff colors are handled via shellAliases.
autoload -U colors && colors
setopt prompt_subst

# Disable the reverse-video (standout) highlight that zsh applies to
# bracketed-pasted text by default (zle_highlight[paste]=standout).
# The inversion makes pasted commands look jarring ("color feels off"
# after paste). Keep the other zle_highlight defaults (region, special,
# suffix, isearch) intact; only neutralize the paste context.
# NOTE: this is independent of the syntax-highlighting plugin — it is
# zsh core behavior, so it applies regardless of which highlighter is
# used (zsh-syntax-highlighting, fast-syntax-highlighting, or none).
zle_highlight=(region:standout special:standout suffix:bold isearch:underline paste:none)
