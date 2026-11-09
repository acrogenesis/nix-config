{ jre, fetchFromGitHub, makeWrapper, maven, }:

maven.buildMavenPackage rec {
  pname = "prometheus-shellyplug-exporter";
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "easimon";
    repo = "shelly-exporter";
    rev = version;
    hash = "sha256-uwd/ZvA0yPnRFLmIfejEdDmHcyW043d16sDnQKeFzyM=";
  };

  mvnHash = "sha256-8jLThm4i8mdway1zYwCTQjxszbvUBqYD0Ww9uFxT0OA=";
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/share/prometheus-shellyplug-exporter
    install -Dm644 target/shelly-*.jar $out/share/prometheus-shellyplug-exporter

    makeWrapper ${jre}/bin/java $out/bin/prometheus-shellyplug-exporter \
      --add-flags "-jar $out/share/prometheus-shellyplug-exporter/shelly-*.jar"
  '';

  patches = [ ./metrics.patch ];

  meta.mainProgram = "prometheus-shellyplug-exporter";

}
