# Meltype as a macOS input method. Upstream ships Meltype.app plus an installer
# that stages the bundle, verifies its signature, swaps it in, and registers it
# with the input source database; this module runs that installer when the
# version changes instead of restating the steps.
#
# Linux is not covered here. There Meltype is an fcitx5 addon, which has to enter
# the input method wrapper on the NixOS side, so it lives in that repository.
{ config, lib, pkgs, ... }:
let
  meltypeVersion = "1.3.0";

  meltype = pkgs.stdenvNoCC.mkDerivation {
    pname = "meltype";
    version = meltypeVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/yksr-melt/Meltype/releases/download/v${meltypeVersion}/Meltype-${meltypeVersion}-mac.zip";
      hash = "sha256-O/NnFB3/n8FrQTPBs8Ky8ARx8S0b3iLgSGCudW1uDUg=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = "Meltype-mac";
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
    meta = {
      description = "Japanese input that types Japanese and English in one romaji stream";
      homepage = "https://github.com/yksr-melt/Meltype";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.darwin;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  # The installer kills the running input method and restarts it, so it runs
  # once per version rather than on every switch.
  marker = "${config.xdg.stateHome}/meltype/installed";
in
{
  home.activation.meltype = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state="${marker}"
    if [[ ! -f "$state" || "$(cat "$state")" != "${meltypeVersion}" ]]; then
      run mkdir -p "$(dirname "$state")"
      # The installer uses ditto, codesign, xattr, and launchctl from the system.
      PATH=/usr/bin:/bin:$PATH run ${pkgs.bash}/bin/bash ${meltype}/install.sh
      run printf '%s\n' "${meltypeVersion}" > "$state"
    fi
  '';
}
