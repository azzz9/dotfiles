# Keep Herdr opt-in: a shell that already belongs to another agent manager
# should not auto-start a second one. Set HERDR_AUTO_START=1 to
# restore the previous behavior for a shell that should run inside Herdr.
if [[ -o interactive \
  && -z "${HERDR_ENV:-}" \
  && -z "${TMUX:-}" \
  && "${HERDR_AUTO_START:-0}" != 0 \
  && "${TERM:-}" != dumb ]] && command -v herdr >/dev/null 2>&1; then
  exec herdr
fi
