{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "unpackerr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.unpackerr;
      defaultText = lib.literalExpression "pkgs.unpackerr";
      description = "Unpackerr package to use.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Working directory for ${service}.";
    };
    configFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/unpackerr/unpackerr.conf";
      description = "Path to the ${service} configuration file.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional environment file for ${service}.";
      example = lib.literalExpression ''
        pkgs.writeText "unpackerr-env" '''
          UN_DEBUG=true
        '''
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${homelab.user} ${homelab.group} - -"
    ];

    systemd.services.${service} = {
      description = "Unpackerr service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        HOME = cfg.configDir;
      };
      serviceConfig = {
        Type = "simple";
        User = homelab.user;
        Group = homelab.group;
        WorkingDirectory = cfg.configDir;
        ExecStart = "${lib.getExe cfg.package} -c ${cfg.configFile}";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
