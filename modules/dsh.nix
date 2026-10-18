{ pkgs, ... }:
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
  dshTui = pkgs.writeShellScriptBin "dsh-tui" ''
    exec ${dsh}/bin/dsh --profile dsh-tui "$@"
  '';
in
{
  home.packages = [ dsh dshTui ];
}
