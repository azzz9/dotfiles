# Meltype (Linux preview) as an fcitx5 addon. Upstream ships a release zip with
# a NativeAOT core, the fcitx5 addon, and the Mozc helper it drives, so there is
# nothing to compile: this derivation lays the pieces out where fcitx5 looks for
# them. The IBus frontend in the zip is not installed; this machine runs fcitx5.
{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
  unzip,
  fcitx5,
  icu,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "meltype";
  version = "1.1.1";

  src = fetchurl {
    url = "https://github.com/yksr-melt/Meltype/releases/download/v${finalAttrs.version}/Meltype-${finalAttrs.version}-linux.zip";
    hash = "sha256-Qx6cHg4GdNMKmW13CPT3oovqViDfSV/hr6WSfBXiN0s=";
  };

  sourceRoot = "Meltype-linux";

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [
    fcitx5
    stdenv.cc.cc.lib
  ];

  # The core dlopens ICU instead of linking it, so it needs an rpath rather
  # than a NEEDED entry. Without one every load aborts the whole fcitx5 process
  # with "Couldn't find a valid ICU package installed on the system".
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [ icu ]} \
      $out/share/meltype/libMeltypeNative.so
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/fcitx5 \
             $out/share/fcitx5/addon \
             $out/share/fcitx5/inputmethod \
             $out/share/meltype/mozc \
             $out/share/licenses/meltype

    # fcitx5 finds the addon through <addon>/lib/fcitx5 and its two configs
    # through <addon>/share/fcitx5. The input method config carries the icon as
    # an absolute path, so that is the only icon this package needs.
    install -m755 fcitx5/meltype.so $out/lib/fcitx5/meltype.so
    install -m644 fcitx5/meltype-addon.conf $out/share/fcitx5/addon/meltype.conf
    sed "s|@DIR@|$out/share/meltype|g" fcitx5/meltype.conf \
      > $out/share/fcitx5/inputmethod/meltype.conf

    install -m755 libMeltypeNative.so $out/share/meltype/libMeltypeNative.so
    install -m755 mozc/meltype_mozc_helper $out/share/meltype/mozc/meltype_mozc_helper
    install -m644 icon.png $out/share/meltype/icon.png

    install -m644 LICENSE THIRD-PARTY-NOTICES.md \
      mozc/MOZC-LICENSE.txt mozc/MOZC-CREDITS.html \
      $out/share/licenses/meltype/

    runHook postInstall
  '';

  meta = {
    description = "Japanese input that types Japanese and English in one romaji stream";
    homepage = "https://github.com/yksr-melt/Meltype";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
