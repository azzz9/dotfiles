{ lib, pkgs, codexPackage, copilotPackage, ompPackage, ... }:
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
  graphify = pkgs.writeShellApplication {
    name = "graphify";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      exec uvx --from graphifyy==0.9.28 graphify "$@"
    '';
  };
  ompExecutable =
    if ompPackage == null then null
    else if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then pkgs.writeShellScriptBin "omp" ''
      # WSL2 can crash in Nix glibc's default hwcaps loader path before Bun
      # starts. Limit glibc's optimized loader selection on that platform.
      if [ -r /proc/sys/kernel/osrelease ] && ${pkgs.gnugrep}/bin/grep -qi microsoft /proc/sys/kernel/osrelease; then
        exec ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
          --glibc-hwcaps-mask x86-64-v2 \
          --library-path ${lib.makeLibraryPath [
            pkgs.glibc
            pkgs.libpulseaudio
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ]} \
          ${ompPackage}/lib/omp/omp "$@"
      fi
      exec ${ompPackage}/bin/omp "$@"
    ''
    else ompPackage;
in
{
  home.packages =
    (with pkgs; [
      # --- General tools ---
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
      solidity.debugpyPython  # DAP debugger

      # --- TypeScript / JavaScript ---
      typescript-language-server  # LSP
      typescript                  # tsserver binary for ts_ls
      biome                       # formatter + linter (biome.json projects)
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
      # nixpkgs unstable made python3.14 the default interpreter, but
      # slither-analyzer's dependency chain (web3 -> eth-tester ->
      # py-evm 0.12.1-beta.1) does not support python3.14 yet, which
      # breaks `dotfiles upgrade`. Use the python3.13 build of
      # slither-analyzer (a self-contained CLI tool) until upstream
      # py-evm adds python3.14 support.
      python313.pkgs.slither-analyzer              # linter / static analysis
      solc                                         # compiler
      solidity.nomicfoundationSolidityLanguageServer  # LSP
      solidity.solhint                             # linter
      solidity.prettierPluginSolidity              # formatter plugin
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      # Temporary: unar fails to link on Darwin because ld64 crashes with
      # `Trace/BPT trap: 5`. Move it back to the common package list once
      # nixos-unstable includes NixOS/nixpkgs#536365.
      unar
      xclip
      wl-clipboard
    ])
    ++ [ graphify roots ]
    ++ lib.optional (codexPackage != null) codexPackage
    ++ lib.optional (copilotPackage != null) copilotPackage
    ++ lib.optional (ompExecutable != null) ompExecutable;

  # Remote Control's daemon commands resolve Codex from this installer-owned
  # path. Point it at the Nix-managed package so pairing remains available
  # without installing a second, self-updating Codex distribution.
  home.file.".codex/packages/standalone/current/codex" = lib.mkIf (codexPackage != null) {
    source = "${codexPackage}/bin/codex";
    force = true;
  };

  # Keep Remote Control in the foreground so systemd, rather than Codex's
  # self-updating daemon, owns its lifecycle.
  systemd.user.services.codex-remote-control = lib.mkIf (
    pkgs.stdenv.isLinux && codexPackage != null
  ) {
    Unit = {
      Description = "Codex Remote Control";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${codexPackage}/bin/codex remote-control";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
