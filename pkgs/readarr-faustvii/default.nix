{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  patchelf,
  musl,
  pkgsMusl,
}:

let
  version = "0.9.0";
  system = stdenv.hostPlatform.system;
  arch =
    {
      x86_64-linux = "x64";
    }
    .${system} or (throw "Unsupported system for readarr-faustvii: ${system}");
  sha256 =
    {
      x86_64-linux = "1k9mzlmzaa6g8lfghvp14k03bizb9a5ljrc8mjfmsa0zimcff0x9";
    }
    .${system} or (throw "Unsupported system for readarr-faustvii: ${system}");
in
stdenv.mkDerivation rec {
  pname = "readarr-faustvii";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Faustvii/Readarr/releases/download/v${version}/Readarr.develop.${version}.linux-musl-${arch}.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [
    makeWrapper
    patchelf
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/${pname}-${version}}
    cp -r * $out/share/${pname}-${version}/.
    chmod +x $out/share/${pname}-${version}/Readarr
    patchelf --set-interpreter ${musl}/lib/ld-musl-x86_64.so.1 \
      $out/share/${pname}-${version}/Readarr
    makeWrapper "$out/share/${pname}-${version}/Readarr" $out/bin/Readarr \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgsMusl.stdenv.cc.cc.lib
          pkgsMusl.stdenv.cc.cc.libgcc
          pkgsMusl.icu
          pkgsMusl.openssl
          pkgsMusl.sqlite
        ]
      }

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Faustvii's Readarr fork packaged for NixOS";
    homepage = "https://github.com/Faustvii/Readarr";
    license = lib.licenses.gpl3;
    maintainers = [ ];
    mainProgram = "Readarr";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = [ "x86_64-linux" ];
  };
}
