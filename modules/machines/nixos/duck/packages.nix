{ lib, pkgs, ... }: {
  services.nextcloud = {
    phpPackage = pkgs.php85;
    # Apply before request parsing, including every FPM worker.
    phpOptions."session.upload_progress.enabled" = "0";
  };

  nixpkgs.overlays = [
    (_final: prev: {
      deluge-2_x = prev.deluge-2_x.override {
        # Deluge still uses the ABI 1 settings and torrent-status properties.
        libtorrent-rasterbar-2_0_x =
          prev.libtorrent-rasterbar-2_1_x.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace CMakeLists.txt \
                --replace-fail 'ENABLED TORRENT_ABI_VERSION=2' 'ENABLED TORRENT_ABI_VERSION=1'
            '';
          });
      };
    })
  ];

  # The channel recipe omits the system libraries used by these Rust crates.
  services.microbin.package = pkgs.microbin.overrideAttrs (old: {
    buildInputs =
      lib.unique ((old.buildInputs or [ ]) ++ [ pkgs.zstd pkgs.sqlite ]);
  });

  # Keep the channel's packages as soon as they catch up with these releases.
  programs.ssh.package = if lib.versionOlder pkgs.openssh.version "10.6p2" then
    pkgs.openssh.overrideAttrs {
      version = "10.6p2";
      src = pkgs.fetchurl {
        url = "mirror://openbsd/OpenSSH/portable/openssh-10.6p2.tar.gz";
        hash = "sha256-muRIcgkM8vBrPPn/FH5/FvMJZxNAdj7S+ZJIOYrinVs=";
      };
    }
  else
    pkgs.openssh;

  services.paperless.package =
    if lib.versionOlder pkgs.paperless-ngx.version "3.4.2" then
      pkgs.callPackage ../../../homelab/services/paperless-ngx/package.nix { }
    else
      pkgs.paperless-ngx;

  services.prowlarr.package =
    if lib.versionOlder pkgs.prowlarr.version "2.7.0.5723" then
      pkgs.callPackage ../../../homelab/services/arr/prowlarr/package.nix { }
    else
      pkgs.prowlarr;

  homelab.services.unpackerr.package =
    if lib.versionOlder pkgs.unpackerr.version "1.0.1" then
      pkgs.callPackage ../../../homelab/services/arr/unpackerr/package.nix { }
    else
      pkgs.unpackerr;

  nix.package =
    if lib.versionOlder pkgs.nixVersions.latest.version "2.35.5" then
      (pkgs.nixVersions.latest.overrideSource (pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nix";
        tag = "2.35.5";
        hash = "sha256-SDSmfEcnZjAf9pz1TPRyzETrWuWTetzwRXSdZLTGVLg=";
      })).overrideScope (_final: _prev: { version = "2.35.5"; })
    else
      pkgs.nixVersions.latest;
}
