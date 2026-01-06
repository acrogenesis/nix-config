{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "phoenix-app";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  hostnames = [ cfg.url ] ++ cfg.aliases;
  phxHost = if cfg.phxHost != null then cfg.phxHost else cfg.url;
  upstream = "http://${cfg.listenAddress}:${toString cfg.port}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "inputs.my-phoenix-app.packages.${pkgs.system}.default";
      description = "Phoenix release package that provides bin/<releaseName>.";
    };
    releaseName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "my_app";
      description = "Release name used for the bin/<releaseName> script.";
    };
    releaseCommand = lib.mkOption {
      type = lib.types.str;
      default = "start";
      description = "Release command to run (for example: start or start_iex).";
    };
    execStart = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the systemd ExecStart command when not using a release package.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Directory for runtime state or uploads.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "phoenix.${homelab.baseDomain}";
    };
    aliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional hostnames that should serve the app.";
    };
    caddy.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to expose the app through Caddy.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    phxHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "PHX_HOST value to expose in the Phoenix runtime.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "phoenix-env" '''
          SECRET_KEY_BASE=super-secret-key
        '''
      '';
    };
    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the Phoenix release.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra runtime packages to add to PATH.";
    };
    cloudflared.credentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "cloudflare-credentials.json" '''
        {"AccountTag":"secret","TunnelSecret":"secret","TunnelID":"secret"}
        '''
      '';
      description = "Path to the Cloudflare tunnel credentials JSON.";
    };
    cloudflared.tunnelId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "00000000-0000-0000-0000-000000000000";
      description = "Cloudflare tunnel ID used to expose the service.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Phoenix App";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Custom Phoenix service";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "phoenix-framework.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      execStart =
        if cfg.execStart != null then
          cfg.execStart
        else if cfg.package != null && cfg.releaseName != null then
          "${cfg.package}/bin/${cfg.releaseName} ${cfg.releaseCommand}"
        else
          throw "${service} requires either execStart or both package and releaseName.";
      baseEnv = {
        MIX_ENV = "prod";
        PHX_HOST = phxHost;
        PHX_SERVER = "true";
        PORT = toString cfg.port;
      };
    in
    lib.mkMerge [
      {
        systemd.tmpfiles.rules = [
          "d ${cfg.configDir} 0750 ${homelab.user} ${homelab.group} - -"
        ];
        systemd.services.${service} = {
          description = "Phoenix application service";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = baseEnv // cfg.extraEnvironment;
          path = [
            pkgs.tesseract
            pkgs.imagemagick
          ]
          ++ cfg.extraPackages;
          serviceConfig = {
            Type = "simple";
            User = homelab.user;
            Group = homelab.group;
            WorkingDirectory = cfg.configDir;
            ExecStart = execStart;
            Restart = "on-failure";
            PrivateTmp = true;
            NoNewPrivileges = true;
          }
          // lib.optionalAttrs (cfg.environmentFile != null) {
            EnvironmentFile = cfg.environmentFile;
          };
        };
        services.caddy.virtualHosts = lib.mkIf cfg.caddy.enable (
          lib.genAttrs hostnames (_: {
            useACMEHost = homelab.baseDomain;
            extraConfig = ''
              reverse_proxy ${upstream}
            '';
          })
        );
      }
      (lib.mkIf (cfg.cloudflared.credentialsFile != null && cfg.cloudflared.tunnelId != null) {
        services.cloudflared = {
          enable = true;
          tunnels.${cfg.cloudflared.tunnelId} = {
            credentialsFile = cfg.cloudflared.credentialsFile;
            default = "http_status:404";
            ingress = lib.genAttrs hostnames (_: {
              service = upstream;
            });
          };
        };
      })
    ]
  );
}
