{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "refun";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  upstream = "http://${cfg.listenAddress}:${toString cfg.port}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Refun Phoenix application";
    package = lib.mkOption {
      type = lib.types.package;
      description = "Refun release package.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 4001;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to environment file with SECRET_KEY_BASE, RELEASE_COOKIE, etc.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = [ service ];
      ensureUsers = [
        {
          name = service;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${homelab.user} ${homelab.group} - -"
    ];

    systemd.services.${service} = {
      description = "Refun Phoenix application";
      after = [ "network.target" "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        MIX_ENV = "prod";
        PHX_HOST = cfg.url;
        PHX_SERVER = "true";
        PORT = toString cfg.port;
        DATABASE_URL = "ecto://${service}@localhost/${service}";
      };
      serviceConfig = {
        Type = "simple";
        User = homelab.user;
        Group = homelab.group;
        WorkingDirectory = cfg.configDir;
        ExecStart = "${cfg.package}/bin/${service} start";
        Restart = "on-failure";
        PrivateTmp = true;
        NoNewPrivileges = true;
        EnvironmentFile = cfg.environmentFile;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy ${upstream}
      '';
    };
  };
}
