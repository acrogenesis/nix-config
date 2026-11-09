{ lib, stdenv, stdenvNoCC, fetchurl, autoPatchelfHook, makeWrapper, openssl, icu
, zlib, libunwind, libuuid, krb5, sqlite, lttng-ust_2_12 }:
let runtimeLibraries = [ openssl icu zlib libunwind libuuid krb5 sqlite ];
in stdenvNoCC.mkDerivation rec {
  pname = "prowlarr";
  version = "2.7.0.5723";
  src = fetchurl {
    url =
      "https://github.com/Prowlarr/Prowlarr/releases/download/v${version}/Prowlarr.master.${version}.linux-core-x64.tar.gz";
    hash = "sha256-1ly5+0Qqij3tBV1wJ9uaCPUZrLeQjHr+chdap8M3eDw=";
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  # The bundled .NET tracing provider uses the liblttng-ust.so.0 ABI.
  buildInputs = [ stdenv.cc.cc.lib lttng-ust_2_12 ] ++ runtimeLibraries;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/prowlarr $out/bin
    cp -r . $out/lib/prowlarr
    makeWrapper $out/lib/prowlarr/Prowlarr $out/bin/Prowlarr \
      --set DOTNET_ROOT $out/lib/prowlarr \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"
    runHook postInstall
  '';
  meta = {
    description = "Indexer manager/proxy for the arr applications";
    homepage = "https://prowlarr.com/";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "Prowlarr";
  };
}
