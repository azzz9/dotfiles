{ config, pkgs, ... }:
let
  repo = "${config.home.homeDirectory}/dotfiles";
  dotfilesSync = pkgs.writeShellScriptBin "dotfiles-sync" ''
    set -euo pipefail

    host="''${1:-default}"
    tmp_dir="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
    lock_dir="$tmp_dir/dotfiles-sync.lockdir"
    nix_conf_dir="$(mktemp -d "$tmp_dir/dotfiles-sync-nix-conf.XXXXXX")"
    patched_activate=""
    have_lock=0
    trap 'rm -rf "$nix_conf_dir"; if [ -n "$patched_activate" ]; then rm -f "$patched_activate"; fi; if [ "$have_lock" = 1 ]; then rmdir "$lock_dir" 2>/dev/null || true; fi' EXIT
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "dotfiles-sync: already running; skipping"
      exit 0
    fi
    have_lock=1

    # Services often start with a minimal PATH.
    # Ensure Home Manager can find `nix` when it re-invokes it internally.
    # Use nix from nixpkgs and an isolated config to avoid host-specific
    # unknown/deprecation warnings from Determinate Nix defaults.
    export PATH="${pkgs.nix}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"
    cat > "$nix_conf_dir/nix.conf" <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
EOF
    export NIX_CONF_DIR="$nix_conf_dir"

    if [ ! -d "${repo}/.git" ]; then
      echo "dotfiles-sync: ${repo} not found" >&2
      exit 1
    fi

    cd "${repo}"

    if [ -n "$(${pkgs.git}/bin/git status --porcelain --untracked-files=normal)" ]; then
      echo "dotfiles-sync: local or untracked changes found in ${repo}; skipping" >&2
      exit 0
    fi

    ${pkgs.git}/bin/git pull --ff-only

    activation_path="$(${pkgs.nix}/bin/nix build --no-link --print-out-paths "${repo}#homeConfigurations.$host.activationPackage" --impure)"
    patched_activate="$(mktemp "$tmp_dir/dotfiles-sync-activate.XXXXXX")"
    ${pkgs.coreutils}/bin/cp "$activation_path/activate" "$patched_activate"
    # Determinate Nix supports `nix profile add`; patch Home Manager's generated
    # command, but fail loudly if the upstream activation script changes shape.
    if ! ${pkgs.gnugrep}/bin/grep -q 'profile install' "$patched_activate"; then
      echo "dotfiles-sync: expected activation profile command not found" >&2
      exit 1
    fi
    ${pkgs.gnused}/bin/sed -i 's/profile install/profile add/g' "$patched_activate"
    ${pkgs.bash}/bin/bash "$patched_activate"
  '';
in
{
  home.packages = [
    dotfilesSync
  ];

}
