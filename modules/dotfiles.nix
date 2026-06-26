{ config, pkgs, ... }:
let
  numtideCache = import ../config/numtide-cache.nix;
  repo = "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  dotfiles = pkgs.writeShellScriptBin "dotfiles" ''
    set -euo pipefail

    usage() {
      cat <<'EOF'
usage: dotfiles <command> [host]

commands:
  apply      apply the current checkout
  sync       pull latest changes, then apply
  upgrade    update flake.lock inputs, then apply
EOF
    }

    command="''${1:-}"
    if [ -z "$command" ] || [ "$command" = "-h" ] || [ "$command" = "--help" ]; then
      usage
      exit 0
    fi
    shift

    # Auto-detect system if no host argument is given.
    # macOS reports "arm64"; Nix expects "aarch64".
    arch="$(uname -m)"
    if [ "$arch" = "arm64" ]; then
      arch="aarch64"
    fi
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    host="''${1:-$arch-$os}"
    tmp_dir="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
    lock_dir="$tmp_dir/dotfiles.lockdir"
    nix_conf_dir="$(mktemp -d "$tmp_dir/dotfiles-nix-conf.XXXXXX")"
    lock_backup=""
    patched_activate=""
    have_lock=0
    trap 'rm -rf "$nix_conf_dir"; if [ -n "$patched_activate" ]; then rm -f "$patched_activate"; fi; if [ -n "$lock_backup" ]; then rm -f "$lock_backup"; fi; if [ "$have_lock" = 1 ]; then rmdir "$lock_dir" 2>/dev/null || true; fi' EXIT
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "dotfiles: already running; skipping"
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

# Numtide binary cache for llm-agents.nix packages (e.g. codex).
# Written here directly because NIX_CONF_DIR replaces the system
# nix.conf; values are sourced from config/numtide-cache.nix (shared
# with flake.nix nixConfig) so the key only lives in one place.
extra-substituters = ${numtideCache.url}
extra-trusted-public-keys = ${numtideCache.key}
EOF
    export NIX_CONF_DIR="$nix_conf_dir"

    if [ ! -d "${repo}/.git" ]; then
      echo "dotfiles: ${repo} not found" >&2
      exit 1
    fi

    cd "${repo}"

    require_clean_repo() {
      status="$(${pkgs.git}/bin/git status --porcelain --untracked-files=normal)"
      if [ -n "$status" ]; then
        echo "dotfiles $command: local or untracked changes found in ${repo}; skipping" >&2
        echo "$status" >&2
        echo "dotfiles $command: commit, stash, or discard local changes first" >&2
        exit 0
      fi
    }

    build_home() {
      activation_path="$(${pkgs.nix}/bin/nix build --no-link --print-out-paths "${repo}#homeConfigurations.$host.activationPackage" --impure)"
      patched_activate="$(mktemp "$tmp_dir/dotfiles-activate.XXXXXX")"
      ${pkgs.coreutils}/bin/cp "$activation_path/activate" "$patched_activate"
    }

    activate_home() {
      # ---
      # Workaround: Determinate Nix supports `nix profile add`; older Home Manager
      # generated scripts use `nix profile install`. Patch the activate script if
      # needed.
      #
      # This sed patch is fragile and version-dependent. Once Home Manager fully
      # migrates to `nix profile add` across all supported versions, this entire
      # block can be removed. If HM switches to a different command form, the
      # `elif` guard below will catch it and exit with an error.
      # ---
      if ${pkgs.gnugrep}/bin/grep -q 'profile install' "$patched_activate"; then
        ${pkgs.gnused}/bin/sed -i 's/profile install/profile add/g' "$patched_activate"
      elif ! ${pkgs.gnugrep}/bin/grep -q 'profile add' "$patched_activate"; then
        echo "dotfiles: expected activation profile command not found" >&2
        exit 1
      fi
      ${pkgs.bash}/bin/bash "$patched_activate"
    }

    apply_home() {
      build_home
      activate_home
    }

    restore_lock() {
      if [ -n "$lock_backup" ] && [ -f "$lock_backup" ]; then
        ${pkgs.coreutils}/bin/cp "$lock_backup" flake.lock
        echo "dotfiles upgrade: restored flake.lock after failure" >&2
      fi
    }

    case "$command" in
      apply)
        apply_home
        ;;
      sync)
        require_clean_repo
        ${pkgs.git}/bin/git pull --ff-only
        apply_home
        ;;
      upgrade)
        require_clean_repo
        lock_backup="$(mktemp "$tmp_dir/dotfiles-flake-lock.XXXXXX")"
        ${pkgs.coreutils}/bin/cp flake.lock "$lock_backup"
        if ! ${pkgs.nix}/bin/nix flake update; then
          restore_lock
          exit 1
        fi
        if ! build_home; then
          restore_lock
          exit 1
        fi
        if ! activate_home; then
          restore_lock
          exit 1
        fi
        ;;
      *)
        echo "dotfiles: unknown command: $command" >&2
        usage >&2
        exit 2
        ;;
    esac
  '';
  dotfilesSync = pkgs.writeShellScriptBin "dotfiles-sync" ''
    exec ${dotfiles}/bin/dotfiles sync "$@"
  '';
  dotfilesUpgrade = pkgs.writeShellScriptBin "dotfiles-upgrade" ''
    exec ${dotfiles}/bin/dotfiles upgrade "$@"
  '';
in
{
  home.packages = [
    dotfiles
    dotfilesSync
    dotfilesUpgrade
  ];
}
