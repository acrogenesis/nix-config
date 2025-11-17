{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "readarr";
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
      default = "Readarr";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Book collection manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "readarr.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Arr";
    };
    package = lib.mkPackageOption pkgs "Readarr" {
      default = pkgs.readarr;
      example = pkgs.readarr-faustvii;
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      package = cfg.package;
      user = homelab.user;
      group = homelab.group;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8787
      '';
    };
  };

}
