# The input method stack, portable across machines. Every scalar is a default,
# so this machine's own configuration.nix can set it.
{ lib, pkgs, ... }:

let
  # Meltype ships a preview zip with no nixpkgs package, so this repository
  # carries the packaging next to the module that installs it.
  meltype = pkgs.callPackage ./meltype.nix { };
in
{
  i18n.inputMethod = {
    enable = lib.mkDefault true;
    type = lib.mkDefault "fcitx5";
    fcitx5.addons = [
      pkgs.fcitx5-mozc
      meltype
    ];
    fcitx5.waylandFrontend = lib.mkDefault true;
  };

  # The addon dlopens its core from a path compiled into it. The default is
  # /opt/meltype and the package cannot move it, so point that path at the store
  # instead of threading an environment variable into whatever starts fcitx5.
  systemd.tmpfiles.rules = [
    "L+ /opt/meltype - - - - ${meltype}/share/meltype"
  ];
}
