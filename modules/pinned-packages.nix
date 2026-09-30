# Derivations this repo pins because nixpkgs does not package them. Every
# updatable derivation keeps the shape nix-update needs (pname, version, and a
# src whose rev or url embeds ${version}), so `dotfiles upgrade` bumps it with
# `nix-update --flake <name>` and no hand edit. codediff-watcher reads its
# version from nixpkgs' codediff-nvim instead and is not in the bump list.
{ pkgs }:
let
  # codediff-watcher tracks the release codediff-nvim's installer downloads.
  # nixpkgs' vimPlugins.codediff-nvim ships the exact plugin source, so read
  # the watcher VERSION out of it; a missing version line must fail the eval
  # rather than hide a mismatch.
  codediffWatcherVersion =
    let
      lua = builtins.readFile (
        pkgs.vimPlugins.codediff-nvim.src + "/lua/codediff/core/installer/watcher.lua"
      );
      match = builtins.match ".*local VERSION = \"([^\"]+)\".*" lua;
    in
    if match == null then
      throw "modules/pinned-packages.nix: no `local VERSION = \"<semver>\"` line found in codediff-nvim's lua/codediff/core/installer/watcher.lua; pin codediff-watcher by hand or update this extract"
    else
      builtins.head match;

  codediffWatcherTarget = {
    "x86_64-linux" = {
      os = "linux";
      arch = "x64";
      hash = "sha256-acXsKVZCUZ952p57kIkK0TLw/YDiiD9v9pZxBqAF27w=";
    };
    "aarch64-darwin" = {
      os = "macos";
      arch = "arm64";
      hash = "sha256-LOudhXiteUsNAYkwbwTQdf7GEdLAYfeL24q4SBri0t4=";
    };
  }.${pkgs.stdenv.hostPlatform.system};

  codediffWatcher = pkgs.stdenvNoCC.mkDerivation {
    pname = "codediff-watcher";
    version = codediffWatcherVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/esmuellert/codediff/releases/download/v${codediffWatcherVersion}/codediff-watcher-${codediffWatcherVersion}-${codediffWatcherTarget.os}-${codediffWatcherTarget.arch}.tar.gz";
      hash = codediffWatcherTarget.hash;
    };
    sourceRoot = ".";
    nativeBuildInputs = pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
    buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.glibc
      pkgs.stdenv.cc.cc.lib
    ];
    installPhase = ''
      install -Dm755 codediff-watcher "$out/bin/codediff-watcher"
    '';
    meta = {
      description = "Native file watcher for codediff.nvim";
      homepage = "https://github.com/esmuellert/codediff";
      license = pkgs.lib.licenses.mit;
      mainProgram = "codediff-watcher";
    };
  };

  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);

  # prettier's --plugin loads dist/index.js, and only the npm-published
  # tarball carries it: v2.4.1's webpack config emits dist/standalone.js and
  # no index.js, so the GitHub tree cannot satisfy the package.json main.
  # The dist package uses a fetchurl of the registry archive so nix-update
  # discovers the version from registry.npmjs.org; bump it in the same run
  # as prettier-plugin-solidity so the two stay on one release.
  prettierPluginSolidityDist = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "prettier-plugin-solidity-dist";
    version = "2.4.1";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/prettier-plugin-solidity/-/prettier-plugin-solidity-${version}.tgz";
      hash = "sha256-V/TVtYr2sDNC2EEgvYqbeJpgScZ18nirVtjrTBKmUtE=";
    };
    installPhase = ''
      mkdir -p $out/dist
      tar -xzf $src -C $out/dist --strip-components=2 package/dist
    '';
  };

  prettierPluginSolidity = pkgs.buildNpmPackage rec {
    pname = "prettier-plugin-solidity";
    version = "2.4.1";
    src = pkgs.fetchFromGitHub {
      owner = "prettier-solidity";
      repo = "prettier-plugin-solidity";
      rev = "v${version}";
      hash = "sha256-A2yrwrDhUN2g27CdU1AlDdw5Zqn+GRXXsOKIlgwb9Ns=";
    };
    npmDepsHash = "sha256-h0uwS6gD2MX7ZeS8gKRyp/Pf9nCVMW106qctQk4i8jQ=";
    postInstall = ''
      rm -rf "$out/lib/node_modules/${pname}/dist"
      cp -r ${prettierPluginSolidityDist}/dist "$out/lib/node_modules/${pname}/dist"
      ln -s ${pkgs.prettier}/lib/node_modules/prettier "$out/lib/node_modules/${pname}/node_modules/prettier"
    '';
  };

  solhint = pkgs.buildNpmPackage rec {
    pname = "solhint";
    version = "6.2.4";
    src = pkgs.fetchFromGitHub {
      owner = "protofire";
      repo = "solhint";
      rev = "v${version}";
      hash = "sha256-A5breqJ+tY2/eAMxiCGrNdQJvg7ofOsdCVLssXL8IVY=";
    };
    npmDepsHash = "sha256-X/qTFf/UPRiKQfOWv8hToleU3EOTiD44T+NyHyN0MVY=";
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
    version = "0.4.2";
    src = pkgs.fetchFromGitHub {
      owner = "k1LoW";
      repo = "roots";
      rev = "v${version}";
      hash = "sha256-neK1K3Emam70LJR/oVi1Gn0dNM+OC6X5TyAufQJE7BQ=";
    };
    vendorHash = "sha256-po/kY9zXId2qvk3oNgdrgFLEbVIWedYjfqMfdX4J5Ls=";
    ldflags = [ "-s" "-w" ];
  };
in
{
  inherit debugpyPython nomicfoundationSolidityLanguageServer codediffWatcher;
  inherit prettierPluginSolidity prettierPluginSolidityDist roots solhint;
}