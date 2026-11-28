# tuios is opt-in: a shell that already belongs to a terminal multiplexer must
# not auto-start a second one. Set TUIOS_AUTO_START=1 to run inside tuios.
if [[ -o interactive \
  && -z "${TUIOS_ENV:-}" \
  && -z "${TMUX:-}" \
  && "${TUIOS_AUTO_START:-0}" != 0 \
  && "${TERM:-}" != dumb ]] && command -v tuios >/dev/null 2>&1; then
  exec tuios
fi
