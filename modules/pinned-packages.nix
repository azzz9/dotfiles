# Derivations this repo pins because nixpkgs does not package them. Every
# updatable derivation keeps the shape nix-update needs (pname, version, and a
# src whose rev or url embeds ${version}), so `bump-pins.sh` bumps it with
# `nix-update --flake <name>` and no hand edit. modules/pin-names.txt names the
# ones it bumps. codediff-watcher is not in that list: its version tracks the
# one codediff-nvim's installer downloads, which the build compares against.
{ pkgs }:
let
  # codediff-watcher tracks the release codediff-nvim's installer downloads.
  # Reading the plugin's VERSION line here would mean reading a derivation during
  # evaluation, which fails on a store that has not built it, so the version is
  # written out and the build below fails when it drifts.
  codediffWatcherVersion = "0.23.2";

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
    # The plugin replaces a watcher whose version differs from its own, so the
    # two have to agree. The source is readable only from a build.
    doCheck = true;
    nativeCheckInputs = [ pkgs.gnugrep ];
    checkPhase = ''
      runHook preCheck
      grep -q 'local VERSION = "${codediffWatcherVersion}"' \
        ${pkgs.vimPlugins.codediff-nvim.src}/lua/codediff/core/installer/watcher.lua
      runHook postCheck
    '';
    meta = {
      description = "Native file watcher for codediff.nvim";
      homepage = "https://github.com/esmuellert/codediff";
      license = pkgs.lib.licenses.mit;
      mainProgram = "codediff-watcher";
    };
  };

  herdrNvim = pkgs.vimUtils.buildVimPlugin rec {
    pname = "herdr-nvim";
    version = "1.2.1";
    src = pkgs.fetchFromGitHub {
      owner = "ChmaraX";
      repo = "herdr-nvim";
      rev = "v${version}";
      hash = "sha256-EghtchK820sWZmq67qdHhKSWkLnG2CqLza/dmUqNNi0=";
    };
    meta = {
      description = "Neovim annotations for Herdr agents";
      homepage = "https://github.com/ChmaraX/herdr-nvim";
      license = pkgs.lib.licenses.mit;
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
    version = "6.2.5";
    src = pkgs.fetchFromGitHub {
      owner = "protofire";
      repo = "solhint";
      rev = "v${version}";
      hash = "sha256-F5RBbq544SK76rtWqYYQU5N6UgQFIMGMPKHJeehnbOE=";
    };
    npmDepsHash = "sha256-s3SVKjyh4UkMvRLeQO8joo0Ng2m+9ljCiqojyiw3wFw=";
    dontNpmBuild = true;
  };

  nomicfoundationSolidityLanguageServer = pkgs.writeShellApplication {
    name = "nomicfoundation-solidity-language-server";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec node "${pkgs.vscode-extensions.nomicfoundation.hardhat-solidity}/share/vscode/extensions/nomicfoundation.hardhat-solidity/server/out/index.js" "$@"
    '';
  };

in
{
  inherit debugpyPython nomicfoundationSolidityLanguageServer codediffWatcher herdrNvim;
  inherit prettierPluginSolidity prettierPluginSolidityDist solhint;
}