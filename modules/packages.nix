{ lib, pkgs, ... }:
let
  pinned = import ./pinned-packages.nix { inherit pkgs; };
in
{
  home.packages =
    (with pkgs; [
      # --- General tools ---
      fastfetch
      git
      openssh
      less
      lazygit
      ghq
      git-wt
      delta
      fd
      ripgrep
      jq
      tree                    # directory structure visualization
      yq-go                   # YAML processor

      # --- Shell ---
      shellcheck              # shell script linter
      shfmt                   # shell script formatter
      bash-language-server    # LSP

      # --- YAML / JSON / TOML ---
      yaml-language-server          # LSP (yaml)
      yamllint                    # linter (yaml)
      vscode-json-languageserver  # LSP (json, jsonc)
      taplo                       # LSP + formatter (toml)

      # --- CSS / HTML ---
      vscode-css-languageserver   # LSP
      vscode-html-languageserver  # LSP
      stylelint                   # linter (css)
      htmlhint                    # linter (html)

      # --- Markdown ---
      markdownlint-cli        # linter

      # --- Security ---
      osv-scanner             # OSV scan of the npm lockfile

      pkgs."nerd-fonts"."jetbrains-mono"

      # --- Lua ---
      lua-language-server    # LSP
      stylua                  # formatter
      selene                  # linter

      # --- Python ---
      pyright                 # LSP
      ruff                    # formatter + linter
      pinned.debugpyPython    # DAP debugger

      # --- TypeScript / JavaScript ---
      typescript-language-server  # LSP
      typescript                  # tsserver binary for ts_ls
      biome                       # formatter + linter (biome.json projects)
      prettier                    # formatter
      prettierd                   # formatter (daemon)
      eslint_d                    # linter (daemon)
      vscode-js-debug             # DAP debugger (Node.js / Chrome)

      # --- C / C++ ---
      clang-tools           # LSP (clangd) + clang-format + clang-tidy

      # --- Nix ---
      nil                       # LSP
      nixpkgs-fmt                # formatter
      statix                    # linter (static analysis)
      deadnix                   # linter (unused bindings)

      # --- Solidity (Hardhat toolchain) ---
      pinned.nomicfoundationSolidityLanguageServer  # LSP
      pinned.solhint                                # linter
      pinned.prettierPluginSolidity                 # formatter plugin
    ])
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
      # Temporary: unar fails to link on Darwin because ld64 crashes with
      # `Trace/BPT trap: 5`. Move it back to the common package list once
      # nixos-unstable includes NixOS/nixpkgs#536365.
      unar
      xclip
      wl-clipboard
    ]);
}
