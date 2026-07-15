{ lib, pkgs, codexPackage, copilotPackage, ... }:
let
  solidity = import ./solidity.nix { inherit pkgs; };
  roots = pkgs.buildGoModule rec {
    pname = "roots";
    version = "0.4.1";
    src = pkgs.fetchFromGitHub {
      owner = "k1LoW";
      repo = "roots";
      rev = "v${version}";
      hash = "sha256-ACMRfWY/lhc3C/KVhuUyS1rgkSHGWPxZrmYt+pXupJI=";
    };
    vendorHash = "sha256-uxcT5VzlTCxxnx09p13mot0wVbbas/otoHdg7QSDt4E=";
    ldflags = [ "-s" "-w" ];
  };
in
{
  home.packages =
    (with pkgs; [
      # --- General tools ---
      openssh
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
      unar
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
      solidity.debugpyPython  # DAP debugger

      # --- TypeScript / JavaScript ---
      typescript-language-server  # LSP
      typescript                  # tsserver binary for ts_ls
      prettier                    # formatter
      prettierd                   # formatter (daemon)
      eslint                      # linter
      eslint_d                    # linter (daemon)
      nodejs                      # runtime
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
      slither-analyzer                             # linter / static analysis
      solc                                         # compiler
      solidity.nomicfoundationSolidityLanguageServer  # LSP
      solidity.solhint                             # linter
      solidity.prettierPluginSolidity              # formatter plugin
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      xclip
      wl-clipboard
    ])
    ++ [ roots ]
    ++ lib.optional (codexPackage != null) codexPackage
    ++ lib.optional (copilotPackage != null) copilotPackage;
}
