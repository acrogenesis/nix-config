{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  service = "teslamate";
  hl = config.homelab;
  cfg = hl.services.${service};
  teslamateUpstream = "http://127.0.0.1:${toString config.services.teslamate.port}";
in
{
  imports = [ inputs.teslamate.nixosModules.default ];

  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to TeslaMate env secrets file.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "teslamate.${hl.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "TeslaMate";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted Tesla data logger";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "teslamate.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      secretsFile = cfg.secretsFile;
      listenAddress = "127.0.0.1";
      virtualHost = cfg.url;
      postgres = {
        enable_server = true;
        # Immich currently expects PostgreSQL < 17 when vectors are enabled.
        package = pkgs.postgresql_16;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy ${teslamateUpstream}
      '';
    };
  };
}
