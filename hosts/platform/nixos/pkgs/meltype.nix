# Meltype (Linux preview) as an fcitx5 addon. The release zip carries the
# NativeAOT core and the Mozc helper it drives, and the addon is rebuilt from the
# same release's source so the mode badge patch can ride along. The IBus frontend
# in the zip is not installed; this machine runs fcitx5.
{
  lib,
  stdenv,
  autoPatchelfHook,
  cmake,
  fetchurl,
  fetchzip,
  unzip,
  fcitx5,
  icu,
}:

let
  version = "1.1.1";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "meltype";
  inherit version;

  src = fetchurl {
    url = "https://github.com/yksr-melt/Meltype/releases/download/v${version}/Meltype-${version}-linux.zip";
    hash = "sha256-Qx6cHg4GdNMKmW13CPT3oovqViDfSV/hr6WSfBXiN0s=";
  };

  # Only for the addon source, which is built below.
  addonSrc = fetchzip {
    url = "https://github.com/yksr-melt/Meltype/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-y3u6KpP5k8JKr/sgyUb2ddIFTLUpsFwHwOlv9vcEpSk=";
  };

  sourceRoot = "Meltype-linux";
  # The zip holds no CMakeLists.txt at its root; the addon is configured by hand
  # in buildPhase.
  dontConfigure = true;

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
    unzip
  ];
  buildInputs = [
    fcitx5
    stdenv.cc.cc.lib
  ];

  buildPhase = ''
    runHook preBuild

    cp -r ${finalAttrs.addonSrc} addon-source
    chmod -R u+w addon-source
    patch -p1 -d addon-source < ${./meltype-mode-badge.patch}
    # Bake the core's location into the addon, so nothing has to set MELTYPE_DIR
    # and no path outside the store is involved.
    cmake -S addon-source/linux/fcitx5 -B addon-build \
      -DMELTYPE_DIR=$out/share/meltype
    cmake --build addon-build -j$NIX_BUILD_CORES

    runHook postBuild
  '';

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
    install -m755 addon-build/meltype.so $out/lib/fcitx5/meltype.so
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
