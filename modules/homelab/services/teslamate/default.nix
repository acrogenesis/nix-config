{
  config,
  inputs,
  lib,
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
    port = lib.mkOption {
      type = lib.types.port;
      default = 4001;
      description = "Local listen port for TeslaMate.";
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
      port = cfg.port;
      virtualHost = cfg.url;
      postgres.enable_server = false;
    };
    # Use the host's shared PostgreSQL instance instead of changing its package.
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "teslamate" ];
      ensureUsers = [
        {
          name = "teslamate";
          ensureDBOwnership = true;
          ensureClauses.login = true;
          ensureClauses.superuser = true;
        }
      ];
    };
    # TeslaMate upstream module does not expose DATABASE_SOCKET_DIR directly.
    # Inject it so we can use the local unix socket without enabling TCP.
    systemd.services.teslamate.environment.DATABASE_SOCKET_DIR = "/run/postgresql";

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy ${teslamateUpstream}
      '';
    };
  };
}
