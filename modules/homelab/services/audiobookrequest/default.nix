{
  config,
  lib,
  ...
}:
let
  service = "audiobookrequest";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    url = lib.mkOption {
      type = lib.types.str;
      default = "abr.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Host port ${service} listens on.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/markbeep/audiobookrequest:1";
      description = "Container image for ${service}.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Persistent config/data directory for ${service}.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "AudioBookRequest";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Audiobook request manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "audiobookshelf.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers.${service} = {
      inherit (cfg) image;
      autoStart = true;
      ports = [ "${toString cfg.port}:8000" ];
      volumes = [ "${cfg.configDir}:/config" ];
      environment = {
        ABR_APP__PORT = "8000";
        ABR_APP__CONFIG_DIR = "/config";
        TZ = homelab.timeZone;
      };
      extraOptions = [
        "--pull=newer"
      ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
