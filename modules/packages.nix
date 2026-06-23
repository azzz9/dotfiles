{ lib, pkgs, codexPackage, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
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
  prettierPluginSolidityDist = pkgs.fetchurl {
    url = "https://registry.npmjs.org/prettier-plugin-solidity/-/prettier-plugin-solidity-2.3.1.tgz";
    hash = "sha256-KQqnnYIFE37d+qa7AB4LECsEcoFeyRfwgCJE6OtLXwA=";
  };
  prettierPluginSolidity = pkgs.buildNpmPackage rec {
    pname = "prettier-plugin-solidity";
    version = "2.3.1";
    src = pkgs.fetchFromGitHub {
      owner = "prettier-solidity";
      repo = "prettier-plugin-solidity";
      rev = "v${version}";
      hash = "sha256-zo5kw8ObjCRubucNe2MKhcjd5uYv9clfolIHtiM6/rQ=";
    };
    npmDepsHash = "sha256-BEk3Sh9NDFVifzCfY6Iq1pesUau3qUi954KR7JPWbZc=";
    postInstall = ''
      rm -rf "$out/lib/node_modules/${pname}/dist"
      tar -xzf ${prettierPluginSolidityDist} -C "$out/lib/node_modules/${pname}" --strip-components=1 package/dist
      ln -s ${pkgs.prettier}/lib/node_modules/prettier "$out/lib/node_modules/${pname}/node_modules/prettier"
    '';
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
      lazygit
      ghq
      git-wt
      delta
      debugpyPython
      codexPackage
      nodejs
      typescript-language-server
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
      lua-language-server
      pyright
      prettier
      prettierd
      eslint
      eslint_d
      stylua
      selene
      ruff
      clang-tools
      foundry
      slither-analyzer
      solc
      nomicfoundationSolidityLanguageServer
      solhint
      prettierPluginSolidity
      pkgs."nerd-fonts"."jetbrains-mono"
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      xclip
      wl-clipboard
    ])
    ++ [ roots ];
}
