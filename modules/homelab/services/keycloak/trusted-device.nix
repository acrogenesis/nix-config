{ lib, fetchFromGitHub, maven, }:

maven.buildMavenPackage rec {
  pname = "keycloak-spi-trusted-device";
  version = "0.0.3";

  src = fetchFromGitHub {
    owner = "wouterh-dev";
    repo = "keycloak-spi-trusted-device";
    rev = "v${version}";
    hash = "sha256-zzJeoLmz0RpFAByL2KZ9+G8B2pQv2ZPw+DxOA8jdKUs=";
  };

  mvnHash = "sha256-6cG3nwZ7Zj2sBHBUN0dMyoKue+5Pj+aA61Lk7JOrS2k=";

  installPhase = ''
    install -D "spi/target/keycloak-spi-trusted-device-1.0-SNAPSHOT.jar" "$out/spi-trusted-device-${version}.jar"
  '';

  meta = with lib; {
    homepage = "https://github.com/wouterh-dev/keycloak-spi-trusted-device";
    description =
      "Third party module that adds OTP trusted device functionality to Keycloak";
    sourceProvenance = with sourceTypes; [ fromSource binaryBytecode ];
    license = licenses.asl20;
    maintainers = with maintainers; [ notthebee ];
  };
}
