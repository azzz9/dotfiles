# The pi package the machines and the `dotfiles` CLI run.
#
# Pi's flake builds the CLI from source, against the nixpkgs pin that flake
# locks. Its install lock points every workspace package at a registry tarball
# and leaves out `integrity`. `nix/package.nix` replaces those tarballs through
# importNpmLock's `packageSourceOverrides`, and the fetcher reads `integrity`
# only for an entry the overrides do not replace, so the packages already
# listed there evaluate with the field missing. `@earendil-works/pi-schema`
# joined that lock in 6536f801 the same way and is not listed. Evaluation of
# `pi-1.4.0` then stops with `attribute 'integrity' missing`. The registry has
# no such tarball, so the fix is the override the other workspace rows already
# use: pack the package the checkout just built and substitute that.
#
# A checkout whose Nix expression already overrides the package, or that has
# no schema package, keeps the flake's own derivation.
{ lib, pi, system }:
let
  piSrc = pi.sourceInfo.outPath;
  packageText = builtins.readFile (piSrc + "/nix/package.nix");
  installLock = piSrc + "/packages/coding-agent/install-lock/package-lock.json";
  schemaPresent =
    builtins.pathExists (piSrc + "/packages/schema/package.json")
    && builtins.pathExists installLock
    && lib.hasInfix ''"node_modules/@earendil-works/pi-schema"'' (builtins.readFile installLock);
  alreadyOverridden = lib.hasInfix "node_modules/@earendil-works/pi-schema" packageText;
  needsPatch = schemaPresent && !alreadyOverridden;
  # The two telemetry lines are the anchor: schema builds beside it, and the
  # override belongs in the same set. Both strings include the trailing
  # newline so the added line keeps the indentation of the file.
  packFrom = "      pack_package packages/telemetry telemetry\n";
  overFrom = "      \"node_modules/@earendil-works/pi-telemetry\" = workspacePackages + \"/telemetry.tgz\";\n";
  patchedText = builtins.replaceStrings
    [
      "./model-catalog.json"
      packFrom
      overFrom
    ]
    [
      # `./model-catalog.json` is resolved next to this file. The patched
      # expression is a single store file, so point the import at the checkout.
      "${piSrc}/nix/model-catalog.json"
      (packFrom + "      pack_package packages/schema schema\n")
      (overFrom + "      \"node_modules/@earendil-works/pi-schema\" = workspacePackages + \"/schema.tgz\";\n")
    ]
    packageText;
  piPkgs = import pi.inputs.nixpkgs { inherit system; };
in
assert lib.assertMsg (!needsPatch || (lib.hasInfix packFrom packageText && lib.hasInfix overFrom packageText))
  "pi nix/package.nix no longer has the telemetry pack and override this patch attaches @earendil-works/pi-schema to";
if needsPatch then
  piPkgs.callPackage (builtins.toFile "package.nix" patchedText) { source = piSrc; }
else
  pi.packages.${system}.pi
