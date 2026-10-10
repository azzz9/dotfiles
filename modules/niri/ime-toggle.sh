#!/bin/sh
# CapsLock arrives here through the xkb imecaps symbol, which turns the key into
# Zenkaku_Hankaku. Meltype toggles its own direct flag inside the engine, where
# nothing outside it can read the flag, so this drives fcitx5's active state
# instead and reports what that state is.
#
# fcitx5-remote reads work without a focused input context and writes need one,
# so the reported mode comes from a read-back rather than from what was asked for.
# A notification is the only channel niri leaves us: fcitx5's own panel is X11.

im=$(fcitx5-remote -n) || exit 0
state=$(fcitx5-remote) || exit 0

if [ "$state" = 2 ]; then
  fcitx5-remote -c
else
  fcitx5-remote -o
fi

state=$(fcitx5-remote) || exit 0
if [ "$state" = 2 ]; then
  mode="あ 日本語入力"
else
  mode="A 英数"
fi

busctl --user --quiet call org.freedesktop.Notifications \
  /org/freedesktop/Notifications org.freedesktop.Notifications Notify \
  susssasa{sv}i fcitx5 0 "" "$im" "$mode" 0 0 1200
