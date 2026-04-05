{ config, pkgs, ... }:
let
  repo = "${config.home.homeDirectory}/dotfiles";
  dotfilesSyncRunner = pkgs.writeShellScriptBin "dotfiles-sync-run" ''
    set -euo pipefail

    host="''${1:-default}"
    lock_file="''${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sync.lock"

    exec 9>"$lock_file"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "dotfiles-sync-run: already running; skipping"
      exit 0
    fi

    if [ ! -d "${repo}/.git" ]; then
      echo "dotfiles-sync-run: ${repo} not found" >&2
      exit 1
    fi

    cd "${repo}"

    if ! ${pkgs.git}/bin/git diff --quiet || ! ${pkgs.git}/bin/git diff --cached --quiet; then
      echo "dotfiles-sync-run: local changes found in ${repo}; skipping" >&2
      exit 0
    fi

    ${pkgs.git}/bin/git pull --ff-only
    ${pkgs.nix}/bin/nix run nixpkgs#home-manager -- switch --flake "${repo}#$host" --impure
  '';
in
{
  home.packages = [
    dotfilesSyncRunner
  ];

  systemd.user.services.dotfiles-sync = {
    Unit = {
      Description = "Sync and apply dotfiles";
      ConditionPathExists = "${repo}/.git";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${dotfilesSyncRunner}/bin/dotfiles-sync-run default";
      TimeoutStartSec = "15min";
    };
  };

  systemd.user.timers.dotfiles-sync = {
    Unit.Description = "Periodic dotfiles sync";
    Timer = {
      Unit = "dotfiles-sync.service";
      OnStartupSec = "2min";
      OnUnitActiveSec = "30min";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
