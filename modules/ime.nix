{ lib, pkgs, ... }:
{
  # fcitx5 rewrites these files when a setting changes in its GUI, so they are
  # copied on every activation instead of linked. This checkout is the source of
  # truth; a GUI change is reverted by the next apply.
  home.activation.fcitx5Config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/install -D -m 600 ${./ime/fcitx5-config} "$HOME/.config/fcitx5/config"
    ${pkgs.coreutils}/bin/install -D -m 600 ${./ime/fcitx5-mozc.conf} "$HOME/.config/fcitx5/conf/mozc.conf"
  '';
}
