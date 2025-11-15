{
  lib,
  stdenv,
  fetchurl,
  libmediainfo,
  sqlite,
  curl,
  makeWrapper,
  icu,
  dotnet-runtime,
  openssl,
  zlib,
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

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/${pname}-${version}}
    cp -r * $out/share/${pname}-${version}/.
    makeWrapper "${dotnet-runtime}/bin/dotnet" $out/bin/Readarr \
      --add-flags "$out/share/${pname}-${version}/Readarr.dll" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          curl
          sqlite
          libmediainfo
          icu
          openssl
          zlib
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
