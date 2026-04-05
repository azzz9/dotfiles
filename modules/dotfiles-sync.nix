{ config, pkgs, ... }:
let
  repo = "${config.home.homeDirectory}/dotfiles";
  dotfilesSyncRunner = pkgs.writeShellScriptBin "dotfiles-sync-run" ''
    set -euo pipefail

    host="''${1:-default}"
    lock_file="''${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sync.lock"
    nix_conf_dir="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sync-nix-conf.XXXXXX")"
    patched_activate=""
    trap 'rm -rf "$nix_conf_dir"; if [ -n "$patched_activate" ]; then rm -f "$patched_activate"; fi' EXIT
    # systemd user services often start with a minimal PATH.
    # Ensure Home Manager can find `nix` when it re-invokes it internally.
    # Use nix from nixpkgs and an isolated config to avoid host-specific
    # unknown/deprecation warnings from Determinate Nix defaults.
    export PATH="${pkgs.nix}/bin:${pkgs.git}/bin:${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"
    cat > "$nix_conf_dir/nix.conf" <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
EOF
    export NIX_CONF_DIR="$nix_conf_dir"

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

    activation_path="$(${pkgs.nix}/bin/nix build --no-link --print-out-paths "${repo}#homeConfigurations.$host.activationPackage" --impure)"
    patched_activate="$(mktemp "''${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sync-activate.XXXXXX")"
    ${pkgs.coreutils}/bin/cp "$activation_path/activate" "$patched_activate"
    ${pkgs.gnused}/bin/sed -i 's/profile install/profile add/g' "$patched_activate"
    ${pkgs.bash}/bin/bash "$patched_activate"
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
