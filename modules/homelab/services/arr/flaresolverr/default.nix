{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "flaresolverr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "FlareSolverr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Proxy server to bypass Cloudflare protection";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "flaresolverr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8191;
      description = "Local port where ${service} listens.";
    };
    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Runtime log level for ${service}.";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.configDir}/.cache 0750 ${homelab.user} ${homelab.group} - -"
      "d ${cfg.configDir}/.local 0750 ${homelab.user} ${homelab.group} - -"
    ];
    systemd.services.${service} = {
      description = "FlareSolverr service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      environment = {
        PORT = toString cfg.port;
        HOST = "127.0.0.1";
        LOG_LEVEL = cfg.logLevel;
        TZ = homelab.timeZone;
        HOME = cfg.configDir;
        XDG_CACHE_HOME = "${cfg.configDir}/.cache";
        XDG_CONFIG_HOME = cfg.configDir;
        XDG_DATA_HOME = cfg.configDir;
      };
      serviceConfig = {
        ExecStart = "${pkgs.flaresolverr}/bin/flaresolverr";
        User = homelab.user;
        Group = homelab.group;
        WorkingDirectory = cfg.configDir;
        Restart = "on-failure";
        RestartSec = 5;
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
