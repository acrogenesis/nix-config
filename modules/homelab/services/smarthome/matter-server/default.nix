{
  config,
  lib,
  ...
}:
let
  homelab = config.homelab;
  cfg = config.homelab.services.matter-server;
in
{
  options.homelab.services.matter-server = {
    enable = lib.mkEnableOption {
      description = "Enable the standalone Matter Server used by Home Assistant";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/opt/services/matter-server";
      description = "Persistent data directory for the Matter Server container";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          matter-server = {
            image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
            autoStart = true;
            extraOptions = [
              "--pull=newer"
              "--network=host"
            ];
            volumes = [ "${cfg.configDir}:/data" ];
            environment = {
              TZ = homelab.timeZone;
            };
          };
        };
      };
    };
  };
}
