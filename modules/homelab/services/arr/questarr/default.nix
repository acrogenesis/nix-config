{ config, lib, ... }:
let
  service = "questarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
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
      default = "ghcr.io/doezer/questarr:latest";
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
      volumes =
        [ "${cfg.configDir}:/app/data" "${cfg.sharedDir}:${cfg.sharedDir}" ];
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
