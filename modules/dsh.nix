{
  config,
  lib,
  pkgs,
  ...
}:
let
  pin = import ./dsh-pin.nix;

  # The wrapper launches the runtime pinned in dsh-pin.nix. DSH_NODE overrides
  # that path.
  dsh = pkgs.writeShellScriptBin "dsh" ''
    bin="''${HOME}/.local/share/dsh/node_modules/.bin/dsh"
    if [ ! -x "$bin" ]; then
      echo "dsh: not installed; run 'dotfiles apply'" >&2
      exit 127
    fi
    node_bin="''${DSH_NODE:-$HOME/.local/share/mise/installs/node/${pin.node}/bin/node}"
    if [ ! -x "$node_bin" ]; then
      echo "dsh: node ${pin.node} is not installed; run 'mise install node@${pin.node}'" >&2
      exit 127
    fi
    exec "$node_bin" "$bin" "$@"
  '';
  # --patch layers after the profile's own cordis.patch.yml, so this route wins
  # over a machine-local edit of the same entry.
  dshTui = pkgs.writeShellScriptBin "dsh-tui" ''
    exec ${dsh}/bin/dsh --profile dsh-tui --patch ${config.xdg.configHome}/dsh/ollama-cloud.patch.yml "$@"
  '';
in
# Every machine imports this module; the guard keeps the layer to Linux.
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  xdg.configFile."dsh/ollama-cloud.patch.yml".source = ./dsh/ollama-cloud.patch.yml;
  home.packages = [
    dsh
    dshTui
  ];
}
