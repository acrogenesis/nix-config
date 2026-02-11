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
  teslamatePostgres = config.services.teslamate.postgres;
  teslamateUpstream = "http://127.0.0.1:${toString config.services.teslamate.port}";
  teslamateDashboards = lib.sources.sourceByRegex (inputs.teslamate + "/grafana/dashboards") [
    "^[^/]*\\.json$"
  ];
  teslamateInternalDashboards = lib.sources.sourceFilesBySuffices (
    inputs.teslamate + "/grafana/dashboards/internal"
  ) [ ".json" ];
  teslamateReportsDashboards = lib.sources.sourceFilesBySuffices (
    inputs.teslamate + "/grafana/dashboards/reports"
  ) [ ".json" ];
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
    grafana.enable = lib.mkEnableOption {
      description = "Provision TeslaMate datasource and dashboards into Grafana";
    };
    grafana.setDefaultDashboard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set TeslaMate home dashboard as Grafana landing page.";
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
    services.grafana = lib.mkIf cfg.grafana.enable {
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "TeslaMate";
            type = "postgres";
            url = "${teslamatePostgres.host}:${toString teslamatePostgres.port}";
            user = teslamatePostgres.user;
            access = "proxy";
            basicAuth = false;
            withCredentials = false;
            isDefault = false;
            secureJsonData.password = "$__env{DATABASE_PASS}";
            jsonData = {
              postgresVersion = 1500;
              sslmode = "disable";
              database = teslamatePostgres.database;
            };
            version = 1;
            editable = true;
          }
        ];
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "teslamate";
              orgId = 1;
              folder = "TeslaMate";
              folderUid = "Nr4ofiDZk";
              type = "file";
              disableDeletion = false;
              allowUiUpdates = true;
              updateIntervalSeconds = 86400;
              options.path = teslamateDashboards;
            }
            {
              name = "teslamate_internal";
              orgId = 1;
              folder = "Internal";
              folderUid = "Nr5ofiDZk";
              type = "file";
              disableDeletion = false;
              allowUiUpdates = true;
              updateIntervalSeconds = 86400;
              options.path = teslamateInternalDashboards;
            }
            {
              name = "teslamate_reports";
              orgId = 1;
              folder = "Reports";
              folderUid = "Nr6ofiDZk";
              type = "file";
              disableDeletion = false;
              allowUiUpdates = true;
              updateIntervalSeconds = 86400;
              options.path = teslamateReportsDashboards;
            }
          ];
        };
      };
      settings.dashboards.default_home_dashboard_path = lib.mkIf cfg.grafana.setDefaultDashboard "${teslamateInternalDashboards}/home.json";
    };
    systemd.services.grafana.serviceConfig.EnvironmentFile = lib.mkIf cfg.grafana.enable [
      cfg.secretsFile
    ];
    assertions = lib.mkIf cfg.grafana.enable [
      {
        assertion = config.homelab.services.grafana.enable;
        message = "homelab.services.teslamate.grafana.enable requires homelab.services.grafana.enable.";
      }
    ];
  };
}
