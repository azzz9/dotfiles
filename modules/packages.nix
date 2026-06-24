{ lib, pkgs, codexPackage, ... }:
let
  solidity = import ./solidity.nix { inherit pkgs; };
  solhint = pkgs.buildNpmPackage rec {
    pname = "solhint";
    version = "6.2.1";
    src = pkgs.fetchFromGitHub {
      owner = "protofire";
      repo = "solhint";
      rev = "v${version}";
      hash = "sha256-1wXgRQdVwRCY+dEmT5O+WsGfkFbYKdSjo/N4Bjhrpis=";
    };
    npmDepsHash = "sha256-y3P+Lgycyp6RCuo2ke4HLkwJw4BPrdyEWeKn5oRs52o=";
    dontNpmBuild = true;
  };
  nomicfoundationSolidityLanguageServer = pkgs.writeShellApplication {
    name = "nomicfoundation-solidity-language-server";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec node "${pkgs.vscode-extensions.nomicfoundation.hardhat-solidity}/share/vscode/extensions/nomicfoundation.hardhat-solidity/server/out/index.js" "$@"
    '';
  };
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
      lazygit
      ghq
      git-wt
      delta
      codexPackage
      yazi
      fd
      ripgrep
      jq
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

      # --- C / C++ ---
      clang-tools           # LSP (clangd) + clang-tidy

      # --- Solidity ---
      foundry                            # forge, cast, anvil
      slither-analyzer                   # linter / static analysis
      solc                               # compiler
      nomicfoundationSolidityLanguageServer  # LSP
      solhint                            # linter
      solidity.prettierPluginSolidity   # formatter plugin
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      xclip
      wl-clipboard
    ])
    ++ [ roots ];
}
