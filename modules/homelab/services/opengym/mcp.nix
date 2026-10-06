{ buildNpmPackage, fetchFromGitHub, makeWrapper, nodejs }:
buildNpmPackage {
  pname = "opengym-mcp";
  version = "0.1.0-unstable-2026-10-06";

  src = fetchFromGitHub {
    owner = "DuarteSantos8";
    repo = "openGym";
    rev = "31c6795b40fb54130192b5016d7dc29e9f457d30";
    hash = "sha256-+SJal22o89THOUHguGhQB4fTBpSp7/MjYCcvFxm26r8=";
  };
  sourceRoot = "source/mcp";
  npmDepsHash = "sha256-e3Hh1RLX9mB636ey7/ooG7UKuEwVB4VkAR6Oao3w8Vc=";
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  # The server imports the frontend's training helpers through
  # ../../frontend/src/lib, so keep that layout next to it.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/opengym/frontend/src
    cp -r . $out/lib/opengym/mcp
    cp -r ../frontend/src/lib $out/lib/opengym/frontend/src/lib

    makeWrapper ${nodejs}/bin/node $out/bin/opengym-mcp \
      --add-flags $out/lib/opengym/mcp/src/index.js

    runHook postInstall
  '';

  # Upstream's guard that the server's import graph loads under plain node.
  doInstallCheck = true;
  installCheckPhase = ''
    ${nodejs}/bin/node $out/lib/opengym/mcp/scripts/check-node-loadable.mjs
  '';
}
