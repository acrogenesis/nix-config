{ lib, stdenvNoCC, fetchurl, versionCheckHook }:
stdenvNoCC.mkDerivation rec {
  pname = "unpackerr";
  version = "1.0.1";
  src = fetchurl {
    url =
      "https://github.com/Unpackerr/unpackerr/releases/download/v${version}/unpackerr_${version}_linux_amd64.tar.gz";
    hash = "sha256-o/fuT8+KWSfG+2l/RpZEMNmy6QHjS98hGQ+6TVZbDKQ=";
  };
  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    install -Dm755 unpackerr $out/bin/unpackerr
    install -Dm644 unpackerr.1.gz $out/share/man/man1/unpackerr.1.gz
    runHook postInstall
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  meta = {
    description = "Extracts downloads for the arr applications";
    homepage = "https://unpackerr.zip";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "unpackerr";
  };
}
