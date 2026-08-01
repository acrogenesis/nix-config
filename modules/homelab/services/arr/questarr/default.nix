{ config, lib, pkgs, ... }:
let
  service = "questarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  # The upstream Alpine image bundles a non-executable, glibc-linked p7zip
  # 16.02 binary. Even with its loader restored, that binary cannot extract
  # common classic multi-volume RAR sets. Keep node-7z's expected CLI shape,
  # but route RAR extraction through unrar and other formats through p7zip.
  archiveExtractor = pkgs.writeShellScript "questarr-7za" ''
    operation="''${1:-}"
    archive="''${2:-}"

    case "$archive" in
      *.rar|*.RAR)
        output=""
        for argument in "$@"; do
          case "$argument" in
            -o*) output="''${argument#-o}" ;;
          esac
        done

        if [ "$operation" = "x" ] && [ -n "$output" ]; then
          exec ${lib.getExe pkgs.unrar} x -o+ -idq "$archive" "$output/"
        fi
        ;;
    esac

    exec ${lib.getExe' pkgs.p7zip "7za"} "$@"
  '';
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Questarr game library manager";
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Host port Questarr listens on.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/doezer/questarr:latest";
      description = "Container image for Questarr.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description =
        "Persistent directory for Questarr's SQLite database and state.";
    };
    sharedDir = lib.mkOption {
      type = lib.types.str;
      default = homelab.mounts.merged;
      description = ''
        Root containing Questarr's download and game library paths. It is
        mounted at the same absolute path in the container so downloader paths
        remain valid and post-processing can use atomic moves.
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Questarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Video game collection and download manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "questarr.png";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    systemd.services."podman-${service}".unitConfig.RequiresMountsFor =
      [ cfg.sharedDir ];

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers.${service} = {
      inherit (cfg) image;
      autoStart = true;
      ports = [ "${toString cfg.port}:5000" ];
      volumes = [
        "${cfg.configDir}:/app/data"
        "${cfg.sharedDir}:${cfg.sharedDir}"
        # The wrapper and its dynamically-linked tools use absolute Nix store
        # paths, so expose the immutable store read-only to the container.
        "/nix/store:/nix/store:ro"
        "${archiveExtractor}:/app/node_modules/7zip-bin/linux/x64/7za:ro"
      ];
      environment = {
        PORT = "5000";
        SQLITE_DB_PATH = "/app/data/sqlite.db";
        PUID = toString config.users.users.${homelab.user}.uid;
        PGID = toString config.users.groups.${homelab.group}.gid;
        TZ = homelab.timeZone;
      };
      extraOptions = [ "--pull=newer" ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
