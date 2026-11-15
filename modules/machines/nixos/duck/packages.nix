{ lib, pkgs, ... }: {
  services.nextcloud = {
    phpPackage = pkgs.php85;
    # Apply before request parsing, including every FPM worker.
    phpOptions."session.upload_progress.enabled" = "0";
  };

  nixpkgs.overlays = [
    (_final: prev: {
      # Glances 4.5.9 replaces the insecure python-jose dependency with PyJWT.
      glances = if lib.versionOlder prev.glances.version "4.5.9" then
        prev.glances.overridePythonAttrs (old: {
          version = "4.5.9";
          src = prev.fetchFromGitHub {
            owner = "nicolargo";
            repo = "glances";
            tag = "v4.5.9";
            hash = "sha256-CvT9GQ29xXTVxC7V2nGmfDhHLsAtF61+XMMLG8cmHww=";
          };
          dependencies = builtins.filter
            (dependency: lib.getName dependency != "python-jose")
            old.dependencies ++ [ prev.python3Packages.pyjwt ];
          # The upstream SMART tests import this optional plugin dependency.
          nativeCheckInputs = (old.nativeCheckInputs or [ ])
            ++ [ prev.python3Packages.pysmart ];
          # Keep every browser/security assertion, but wait for API readiness.
          postPatch = (old.postPatch or "") + ''
            substituteInPlace tests/test_browser_restful.py \
              --replace-fail '    time.sleep(5)' '    deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    if pid.poll() is not None:
                        raise RuntimeError(f"Glances browser exited with code {pid.returncode}")
                    try:
                        if requests.get(f"{URL}/serverslist", timeout=1).ok:
                            break
                    except requests.exceptions.RequestException:
                        pass
                    time.sleep(0.1)
                else:
                    pid.terminate()
                    pid.wait(timeout=5)
                    raise RuntimeError("Glances browser API was not ready within 30 seconds")'
          '';
        })
      else
        prev.glances;

      # Apply the patch release to every SSH consumer, including Restic/Mosh.
      openssh = if lib.versionOlder prev.openssh.version "10.6p2" then
        prev.openssh.overrideAttrs {
          version = "10.6p2";
          src = prev.fetchurl {
            url = "mirror://openbsd/OpenSSH/portable/openssh-10.6p2.tar.gz";
            hash = "sha256-muRIcgkM8vBrPPn/FH5/FvMJZxNAdj7S+ZJIOYrinVs=";
          };
        }
      else
        prev.openssh;

      nextcloud35 = if lib.versionOlder prev.nextcloud35.version "35.0.3" then
        prev.nextcloud35.overrideAttrs {
          version = "35.0.3";
          src = prev.fetchurl {
            url =
              "https://download.nextcloud.com/server/releases/nextcloud-35.0.3.tar.bz2";
            hash = "sha256-WEAUQM6Bt/jURajCqAJ1crYW74NZL5axIf0V7Ioa7TU=";
          };
        }
      else
        prev.nextcloud35;

      seerr = if lib.versionOlder prev.seerr.version "3.5.2" then
        prev.seerr.overrideAttrs (finalAttrs: _old: {
          version = "3.5.2";
          src = prev.fetchFromGitHub {
            owner = "seerr-team";
            repo = "seerr";
            tag = "v3.5.2";
            hash = "sha256-kwbGwWiB0F4GbI+/Q4NKW9hrbIn8yaS5FmA8eImIFVA=";
          };
          pnpmDeps = prev.fetchPnpmDeps {
            inherit (finalAttrs) pname version src;
            pnpm = prev.pnpm_10.override { nodejs-slim = prev.nodejs-slim_22; };
            fetcherVersion = 3;
            hash = "sha256-NiptqZ+r8JsH47sapaKPo3D3DojCn6j0g/OXkhmjNuU=";
          };
        })
      else
        prev.seerr;

      grafana = if lib.versionOlder prev.grafana.version "13.3.1" then
        prev.grafana.overrideAttrs (finalAttrs: old: {
          version = "13.3.1";
          src = prev.fetchFromGitHub {
            owner = "grafana";
            repo = "grafana";
            tag = "v13.3.1";
            hash = "sha256-sv8RHis7EioA2AmaLMfuBfIVuq0P8Hn7det741x+DfY=";
          };
          vendorHash = "sha256-LCvahHjznJcC04bT2eyRkpe5z7tIQLGQ+FqUmqjrxJQ=";
          offlineCache = prev.yarn-berry_4-fetcher.fetchYarnBerryDeps {
            inherit (finalAttrs) src;
            inherit (old) missingHashes;
            hash = "sha256-MG3ugZgGmZwlU7ZJzwIhH7c/eJLdkzbR3ZsZllf7/dQ=";
          };
        })
      else
        prev.grafana;

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

  systemd.package = if lib.versionOlder pkgs.systemd.version "262.2" then
    pkgs.systemd.overrideAttrs (old: {
      version = "262.2";
      src = pkgs.fetchFromGitHub {
        owner = "systemd";
        repo = "systemd";
        tag = "v262.2";
        hash = "sha256-BNL7ah1mtw4G94Sbuj9RL7/XDliI3lZFi0XBeQcMtqg=";
      };
      patches = map (patch:
        if lib.hasSuffix "/0004-core-don-t-taint-on-unmerged-usr.patch"
        (toString patch) then
          ./systemd-unmerged-usr.patch
        else
          patch) old.patches;
    })
  else
    pkgs.systemd;

  # The channel recipe omits the system libraries used by these Rust crates.
  services.microbin.package = pkgs.microbin.overrideAttrs (old: {
    buildInputs =
      lib.unique ((old.buildInputs or [ ]) ++ [ pkgs.zstd pkgs.sqlite ]);
  });

  programs.ssh.package = pkgs.openssh;

  services.paperless.package = let
    package = if lib.versionOlder pkgs.paperless-ngx.version "3.4.2" then
      pkgs.callPackage ../../../homelab/services/paperless-ngx/package.nix { }
    else
      pkgs.paperless-ngx;
  in if package.version == "3.4.2"
  && lib.versions.majorMinor pkgs.python3Packages.torch.version == "2.15" then
    package.overrideAttrs (old: {
      # Keep this compatibility allowance limited to the tested version pair.
      pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "torch" ];
    })
  else
    package;

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
