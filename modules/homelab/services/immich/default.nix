{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.services.immich;
  homelab = config.homelab;
in
{
  options.homelab.services.immich = {
    enable = lib.mkEnableOption "Self-hosted photo and video management solution";
    user = lib.mkOption {
      default = "immich";
      type = lib.types.str;
      description = ''
        User to run the Immich container as
      '';
    };
    group = lib.mkOption {
      default = config.homelab.group;
      type = lib.types.str;
      description = ''
        Group to run the Immich container as
      '';
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.homelab.mounts.merged}/Photos/Immich";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/immich";
      description = "Directory containing Immich application state.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "photos.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Immich";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted photo and video management solution";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "immich.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0775 ${cfg.user} ${homelab.group} - -"
      "d ${cfg.configDir} 0770 ${cfg.user} ${homelab.group} - -"
      "d /var/cache/immich-machine-learning/matplotlib 0770 ${cfg.user} ${homelab.group} - -"
    ];
    users.users.${cfg.user}.extraGroups = lib.mkBefore [
      "video"
      "render"
    ];
    services.immich = {
      user = cfg.user;
      group = homelab.group;
      enable = true;
      port = 2283;
      mediaLocation = "${cfg.mediaDir}";
    };
    systemd.services = {
      immich-server.serviceConfig.RequiresMountsFor = [ cfg.mediaDir ];
      immich-server.serviceConfig.DeviceAllow = [ "/dev/dri/renderD128" ];
      immich-server.serviceConfig.PrivateDevices = lib.mkForce false;
      immich-machine-learning.serviceConfig.Environment = [
        "MPLCONFIGDIR=/var/cache/immich-machine-learning/matplotlib"
      ];
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://${config.services.immich.host}:${toString config.services.immich.port}
      '';
    };
  };

}
