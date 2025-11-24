{
  config,
  lib,
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
      default = 1053;
      description = "Host port for DNS (UDP/TCP) to avoid clashing with existing resolvers.";
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
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0770 ${homelab.user} ${homelab.group} - -" ];

    networking.firewall = {
      allowedTCPPorts = [ cfg.dnsPort ];
      allowedUDPPorts = [ cfg.dnsPort ];
    };

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers.${service} = {
      image = "technitium/dns-server:latest";
      autoStart = true;
      extraOptions = [
        "--pull=newer"
      ];
      environment = {
        TZ = homelab.timeZone;
        PUID = toString config.users.users.${homelab.user}.uid;
        PGID = toString config.users.groups.${homelab.group}.gid;
      };
      volumes = [
        "${cfg.configDir}:/etc/dns/config"
      ];
      ports = [
        "${cfg.dnsListenAddress}:${toString cfg.dnsPort}:53/udp"
        "${cfg.dnsListenAddress}:${toString cfg.dnsPort}:53/tcp"
        "${cfg.webListenAddress}:${toString cfg.webPort}:5380/tcp"
      ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy ${upstream}
      '';
    };
  };
}
