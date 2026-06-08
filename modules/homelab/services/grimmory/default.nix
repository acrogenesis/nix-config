{ config, lib, ... }:
let
  service = "grimmory";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  dbService = "${service}-mariadb";
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    url = lib.mkOption {
      type = lib.types.str;
      default = "grimmory.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 6060;
      description = "Host port ${service} listens on.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/grimmory-tools/grimmory:latest";
      description = "Container image for ${service}.";
    };
    databaseImage = lib.mkOption {
      type = lib.types.str;
      default = "lscr.io/linuxserver/mariadb:11.4.5";
      description = "MariaDB container image for ${service}.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Persistent application state directory for ${service}.";
    };
    booksDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.merged}/Media/Books";
      description = "Host path exposed as Grimmory's book library.";
    };
    bookdropDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.merged}/Media/Books/Bookdrop";
      description = "Host path exposed as Grimmory's Bookdrop import folder.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Environment file containing DATABASE_PASSWORD, MYSQL_PASSWORD, and MYSQL_ROOT_PASSWORD.
        DATABASE_PASSWORD and MYSQL_PASSWORD must have the same value.
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Grimmory";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted digital library";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bookstack.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.configDir}/data 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.configDir}/mariadb 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.booksDir} 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.bookdropDir} 0775 ${homelab.user} ${homelab.group} - -"
    ];

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers = {
      ${dbService} = {
        image = cfg.databaseImage;
        autoStart = true;
        volumes = [ "${cfg.configDir}/mariadb:/config" ];
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          PUID = toString config.users.users.${homelab.user}.uid;
          PGID = toString config.users.groups.${homelab.group}.gid;
          TZ = homelab.timeZone;
          MYSQL_DATABASE = "grimmory";
          MYSQL_USER = "grimmory";
        };
        extraOptions = [ "--pull=newer" "--network-alias=${dbService}" ];
      };
      ${service} = {
        inherit (cfg) image;
        autoStart = true;
        dependsOn = [ dbService ];
        ports = [ "${toString cfg.port}:${toString cfg.port}" ];
        volumes = [
          "${cfg.configDir}/data:/app/data"
          "${cfg.booksDir}:/books"
          "${cfg.bookdropDir}:/bookdrop"
        ];
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          USER_ID = toString config.users.users.${homelab.user}.uid;
          GROUP_ID = toString config.users.groups.${homelab.group}.gid;
          TZ = homelab.timeZone;
          DATABASE_URL = "jdbc:mariadb://${dbService}:3306/grimmory";
          DATABASE_USERNAME = "grimmory";
          BOOKLORE_PORT = toString cfg.port;
        };
        extraOptions = [ "--pull=newer" ];
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
