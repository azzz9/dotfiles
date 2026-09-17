# Keep Herdr opt-in: Orca/SSH provides its own agent UI, so auto-starting
# Herdr here would create a second agent manager. Set HERDR_AUTO_START=1 to
# restore the previous behavior for a shell that should run inside Herdr.
if [[ -o interactive \
  && -z "${HERDR_ENV:-}" \
  && -z "${TMUX:-}" \
  && "${HERDR_AUTO_START:-0}" != 0 \
  && "${TERM:-}" != dumb ]] && command -v herdr >/dev/null 2>&1; then
  exec herdr
fi
