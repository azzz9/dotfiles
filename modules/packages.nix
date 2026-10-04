{ lib, pkgs, ... }:
let
  pinned = import ./pinned-packages.nix { inherit pkgs; };
  graphify = pkgs.writeShellApplication {
    name = "graphify";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      # graphify refreshes ~/.agents/skills/graphify on every run. That path is
      # a Nix-managed symlink into this repo, so the refresh would overwrite
      # tracked skill files with the generic agents variant.
      export GRAPHIFY_NO_AUTO_REFRESH=1
      exec uvx --from graphifyy==0.9.73 graphify "$@"
    '';
  };
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
      yazi
      fd
      ripgrep
      jq
      tree                    # directory structure visualization
      yq-go                   # YAML processor
      shellcheck              # shell script linter
      shfmt                   # shell script formatter
      poppler-utils
      ffmpegthumbnailer
      p7zip
      imagemagick
      resvg
      tree-sitter
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
      eslint                      # linter
      eslint_d                    # linter (daemon)
      mise                        # tool version manager; versions belong to each environment
      bun                         # runtime for the pstack port's bundled scripts
      vscode-js-debug             # DAP debugger (Node.js / Chrome)

      # --- C / C++ ---
      clang-tools           # LSP (clangd) + clang-tidy

      # --- Nix ---
      nil                       # LSP
      nixpkgs-fmt                # formatter
      statix                    # linter (static analysis)
      deadnix                   # linter (unused bindings)

      # --- Solidity ---
      foundry                                      # forge, cast, anvil
      # nixpkgs unstable made python3.14 the default interpreter, but
      # slither-analyzer's dependency chain (web3 -> eth-tester ->
      # py-evm 0.12.1-beta.1) does not support python3.14 yet, which
      # breaks `dotfiles upgrade`. Use the python3.13 build of
      # slither-analyzer (a self-contained CLI tool) until upstream
      # py-evm adds python3.14 support.
      python313.pkgs.slither-analyzer              # linter / static analysis
      solc                                         # compiler
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
    ])
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin (with pkgs; [
      terminal-notifier
    ])
    ++ [ graphify pinned.roots ];
}
