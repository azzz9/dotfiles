#!/usr/bin/env bash
# Installs the dsh CLI into the dotfiles-owned prefix, keeps the dsh-tui
# profile plugin on the pinned version, and provisions the pinned Node runtime.
#
# dotfiles-cli.nix inlines this file into the `dotfiles` CLI.
dsh_reconcile() {
  local prefix bin installed dsh_home nodedir python_bin pin_file
  local dsh_cli_version dsh_tui_version dsh_node_version node_bin marker built
  prefix="${HOME}/.local/share/dsh"
  bin="$prefix/node_modules/.bin/dsh"
  dsh_home="${DSH_HOME:-$HOME/.dsh}"

  # Read the pins from the checkout, not from the CLI's baked environment: a
  # bump made by `dotfiles upgrade` must reach the reconcile in the same run.
  if [ -z "${DOTFILES_DIR:-}" ]; then
    echo "dotfiles: DOTFILES_DIR is not set" >&2
    return 1
  fi
  pin_file="${DOTFILES_DIR}/modules/dsh-pin.nix"
  dsh_cli_version="$(sed -n 's/^  cli = "\(.*\)";$/\1/p' "$pin_file")"
  dsh_tui_version="$(sed -n 's/^  tui = "\(.*\)";$/\1/p' "$pin_file")"
  dsh_node_version="$(sed -n 's/^  node = "\(.*\)";$/\1/p' "$pin_file")"
  if [ -z "$dsh_cli_version" ] || [ -z "$dsh_tui_version" ] || [ -z "$dsh_node_version" ]; then
    echo "dotfiles: could not read the dsh pins from $pin_file" >&2
    return 1
  fi

  node_bin="${HOME}/.local/share/mise/installs/node/${dsh_node_version}/bin/node"
  if [ ! -x "$node_bin" ]; then
    echo "dotfiles: installing node@$dsh_node_version for dsh"
    if ! mise install "node@$dsh_node_version" < /dev/null; then
      echo "dotfiles: could not install node@$dsh_node_version; rerun online: dotfiles apply" >&2
      return 1
    fi
  fi

  installed="$(jq -r .version "$prefix/node_modules/@deepseek-ai/dsh/package.json" 2>/dev/null || true)"
  marker="$prefix/.native-built"
  built="$(cat "$marker" 2>/dev/null || true)"
  if [ "$installed" != "$dsh_cli_version" ] || [ "$built" != "$dsh_cli_version" ]; then
    echo "dotfiles: installing @deepseek-ai/dsh@$dsh_cli_version"
    rm -f "$marker"
    mkdir -p "$prefix"
    # npm 11 blocks install scripts until they are listed under allowScripts.
    if [ ! -f "$prefix/package.json" ]; then
      printf '{"name":"dotfiles-dsh","private":true,"dependencies":{}}\n' > "$prefix/package.json"
    fi
    jq --arg version "$dsh_cli_version" \
      '.dependencies = ((.dependencies // {}) + {"@deepseek-ai/dsh": $version})' \
      "$prefix/package.json" > "$prefix/package.json.tmp"
    mv "$prefix/package.json.tmp" "$prefix/package.json"
    # node-gyp has to use the Nix node's headers. node-pty ships a prebuilt
    # binary that NixOS cannot load, so build it from source. The Nix toolchain
    # provides Python 3.12.
    nodedir="$(dirname "$(dirname "$(command -v node)")")"
    python_bin="$(command -v python3.12 || command -v python3 || true)"
    if ! npm_config_nodedir="$nodedir" \
         npm_config_build_from_source=true \
         npm_config_python="${python_bin:-python3}" \
         npm install --prefix "$prefix" --no-audit --no-fund; then
      echo "dotfiles: could not install dsh@$dsh_cli_version; rerun online: dotfiles apply" >&2
      return 1
    fi
    if ! (cd "$prefix" && npm install-scripts approve --all); then
      echo "dotfiles: could not approve the dsh install scripts" >&2
      return 1
    fi
    if ! npm_config_nodedir="$nodedir" \
         npm_config_build_from_source=true \
         npm_config_python="${python_bin:-python3}" \
         npm rebuild --prefix "$prefix" --build-from-source; then
      echo "dotfiles: could not build the dsh native modules" >&2
      return 1
    fi
    printf '%s\n' "$dsh_cli_version" > "$marker"
  fi

  installed="$(jq -r .version "$dsh_home/profiles/dsh-tui/node_modules/@deepseek-harness-tui/dsh-tui/package.json" 2>/dev/null || true)"
  if [ "$installed" != "$dsh_tui_version" ]; then
    echo "dotfiles: installing @deepseek-harness-tui/dsh-tui@$dsh_tui_version"
    if ! "$bin" plugin --profile dsh-tui add "@deepseek-harness-tui/dsh-tui@$dsh_tui_version" < /dev/null; then
      echo "dotfiles: could not install the dsh-tui profile; rerun online: dotfiles apply" >&2
      return 1
    fi
  fi
}
