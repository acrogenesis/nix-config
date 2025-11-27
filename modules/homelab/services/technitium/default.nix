{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "technitium";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  upstream = "http://127.0.0.1:${toString cfg.webPort}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = if pkgs ? technitium-dns-server then pkgs.technitium-dns-server else null;
      defaultText = lib.literalExpression "pkgs.technitium-dns-server";
      description = "Technitium DNS Server package to use.";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description = "Directory containing Technitium DNS Server state.";
    };
    dnsListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind the DNS listener to.";
      example = "192.168.1.2";
    };
    dnsPort = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = "Host port for DNS (UDP/TCP).";
    };
    webListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the management UI listener.";
    };
    webPort = lib.mkOption {
      type = lib.types.port;
      default = 5380;
      description = "Host port for the management UI.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "dns.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Technitium DNS";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted DNS server";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "ddns-updater.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "homelab.services.${service}.package is null; pkgs.technitium-dns-server is not available on this platform.";
      }
    ];

    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0770 ${homelab.user} ${homelab.group} - -" ];

    networking.firewall = {
      allowedTCPPorts = [ cfg.dnsPort ];
      allowedUDPPorts = [ cfg.dnsPort ];
    };

    systemd.services.${service} = {
      description = "Technitium DNS Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.configDir;
        ExecStart = "${cfg.package}/bin/technitium-dns-server ${cfg.configDir}";
        Environment = [
          "ASPNETCORE_URLS=http://${cfg.webListenAddress}:${toString cfg.webPort}"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        User = homelab.user;
        Group = homelab.group;
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.configDir ];
        DevicePolicy = "closed";
        PrivateTmp = true;
        RequiresMountsFor = [ cfg.configDir ];
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
