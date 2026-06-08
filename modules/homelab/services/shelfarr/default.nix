{ config, lib, ... }:
let
  service = "shelfarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    url = lib.mkOption {
      type = lib.types.str;
      default = "shelfarr.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5056;
      description = "Host port ${service} listens on.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/pedro-revez-silva/shelfarr:latest";
      description = "Container image for ${service}.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Persistent storage directory for ${service}.";
    };
    audiobookDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.merged}/Media/Books/Audiobooks";
      description = "Host path where Shelfarr writes completed audiobooks.";
    };
    ebookDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.merged}/Media/Books/Ebooks";
      description = "Host path where Shelfarr writes completed ebooks.";
    };
    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "${homelab.mounts.merged}/Downloads.tmp/Shelfarr";
      description =
        "Host path where Shelfarr sees completed downloads before processing.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Shelfarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Book and audiobook request manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bookstack.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.audiobookDir} 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.ebookDir} 0775 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.downloadDir} 0775 ${homelab.user} ${homelab.group} - -"
    ];

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers.${service} = {
      inherit (cfg) image;
      autoStart = true;
      ports = [ "${toString cfg.port}:8080" ];
      volumes = [
        "${cfg.configDir}:/rails/storage"
        "${cfg.audiobookDir}:/audiobooks"
        "${cfg.ebookDir}:/ebooks"
        "${cfg.downloadDir}:/downloads"
      ];
      environment = {
        HTTP_PORT = "8080";
        SOLID_QUEUE_IN_PUMA = "1";
        PUID = toString config.users.users.${homelab.user}.uid;
        PGID = toString config.users.groups.${homelab.group}.gid;
      };
      extraOptions = [ "--pull=newer" "--tmpfs=/rails/tmp:rw,mode=1777" ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
