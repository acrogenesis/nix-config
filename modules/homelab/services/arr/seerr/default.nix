{ pkgs, config, lib, options, ... }:
let
  service = "seerr";
  upstreamService = if options.services ? seerr then "seerr" else "jellyseerr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption { description = "Enable ${service}"; };
    url = lib.mkOption {
      type = lib.types.str;
      default = "jellyseerr.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyseerr/config";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = if pkgs ? seerr then pkgs.seerr else pkgs.jellyseerr;
      defaultText = lib.literalExpression "pkgs.seerr";
      description = "The Seerr package to use.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Seerr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Media request and discovery manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "seerr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${upstreamService} = {
      enable = true;
      port = cfg.port;
      package = cfg.package;
      configDir = cfg.configDir;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
