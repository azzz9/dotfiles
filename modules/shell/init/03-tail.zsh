export NVM_DIR="$HOME/.nvm"

_lazy_load_nvm() {
  unset -f nvm node npm npx corepack _lazy_load_nvm
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  else
    echo "nvm: NVM not found at $NVM_DIR/nvm.sh; using system node" >&2
  fi
}

nvm() { _lazy_load_nvm; nvm "$@"; }
node() { _lazy_load_nvm; command node "$@"; }
npm() { _lazy_load_nvm; command npm "$@"; }
npx() { _lazy_load_nvm; command npx "$@"; }
corepack() { _lazy_load_nvm; command corepack "$@"; }

if [[ -o interactive \
  && -z "${TMUX:-}" \
  && "${TMUX_AUTO_START:-1}" != 0 \
  && "${TERM:-}" != dumb ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi
