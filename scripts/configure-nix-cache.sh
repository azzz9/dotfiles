#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_CONFIG="$SCRIPT_DIR/../config/numtide-cache.nix"
CACHE_URL=""
CACHE_KEY=""
MARKER="# dotfiles: Numtide binary cache"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

cache_is_configured() {
  local config

  config="$(nix config show 2>/dev/null)"
  grep "^substituters = " <<<"$config" | grep -Fq "$CACHE_URL" \
    && grep "^trusted-public-keys = " <<<"$config" | grep -Fq "$CACHE_KEY"
}

select_config_file() {
  if [[ -e /etc/nix/nix.custom.conf ]] \
    || grep -Eq '^[[:space:]]*!?include[[:space:]]+nix\.custom\.conf' /etc/nix/nix.conf 2>/dev/null; then
    printf '%s\n' "/etc/nix/nix.custom.conf"
  else
    printf '%s\n' "/etc/nix/nix.conf"
  fi
}

restart_nix_daemon() {
  case "$(uname -s)" in
    Linux)
      if command_exists systemctl; then
        sudo systemctl restart nix-daemon.service
      else
        echo "configure-nix-cache: systemctl not found; restart nix-daemon manually" >&2
        return 1
      fi
      ;;
    Darwin)
      if sudo launchctl print system/systems.determinate.nix-daemon >/dev/null 2>&1; then
        sudo launchctl kickstart -k system/systems.determinate.nix-daemon
      elif sudo launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
        sudo launchctl kickstart -k system/org.nixos.nix-daemon
      else
        echo "configure-nix-cache: nix-daemon launchd service not found" >&2
        return 1
      fi
      ;;
    *)
      echo "configure-nix-cache: unsupported OS: $(uname -s)" >&2
      return 1
      ;;
  esac
}

main() {
  local config_file
  local tmp_file

  if ! command_exists nix; then
    echo "configure-nix-cache: nix is not installed" >&2
    exit 1
  fi

  CACHE_URL="$(nix eval --raw --file "$CACHE_CONFIG" url)"
  CACHE_KEY="$(nix eval --raw --file "$CACHE_CONFIG" key)"

  if cache_is_configured; then
    exit 0
  fi

  config_file="$(select_config_file)"
  if [[ -e "$config_file" && ! -r "$config_file" ]]; then
    echo "configure-nix-cache: cannot read $config_file" >&2
    exit 1
  fi

  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' EXIT

  if [[ -r "$config_file" ]]; then
    cp "$config_file" "$tmp_file"
  fi

  if ! grep -Fqx "$MARKER" "$tmp_file"; then
    cat >>"$tmp_file" <<CACHE_CONFIG

$MARKER
extra-substituters = $CACHE_URL
extra-trusted-substituters = $CACHE_URL
extra-trusted-public-keys = $CACHE_KEY
CACHE_CONFIG
  fi

  echo "Configuring the Numtide binary cache in $config_file (sudo required)..."
  sudo install -m 0644 "$tmp_file" "$config_file"
  restart_nix_daemon

  if ! cache_is_configured; then
    echo "configure-nix-cache: cache settings did not take effect" >&2
    exit 1
  fi
}

main "$@"
