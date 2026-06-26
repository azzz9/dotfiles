# Shared Solidity derivations used by modules/nvim.nix and modules/packages.nix.
# Import as: solidity = import ./solidity.nix { inherit pkgs; };
{ pkgs }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);

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
in
{
  inherit debugpyPython prettierPluginSolidity solhint nomicfoundationSolidityLanguageServer;
}
