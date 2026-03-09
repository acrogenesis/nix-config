{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  config = lib.mkIf config.homelab.services.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    environment.etc."caddy/errors".source = ../../../assets/errors;
    security.acme = {
      acceptTerms = true;
      defaults.email = "adrian@acrogenesis.com";
      certs.${config.homelab.baseDomain} = {
        reloadServices = [ "caddy.service" ];
        domain = "${config.homelab.baseDomain}";
        extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
        # Cloudflare API can report TXT records before they're visible from all
        # DNS vantage points; use a fixed wait to avoid premature renew failures.
        extraLegoFlags = [
          "--dns.propagation-wait"
          "5m"
        ];
        group = config.services.caddy.group;
        environmentFile = config.homelab.cloudflare.dnsCredentialsFile;
      };
    };
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        "http://${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };

        "*.${config.homelab.baseDomain}" = {
          useACMEHost = config.homelab.baseDomain;
          extraConfig = ''
            root * /etc/caddy/errors
            @missing not file
            handle @missing {
              rewrite * /404.html
              file_server {
                status 404
              }
            }
            handle {
              file_server
            }
          '';
        };

      };
    };
    nixpkgs.config.permittedInsecurePackages = [
      "dotnet-sdk-6.0.428"
      "aspnetcore-runtime-6.0.36"
    ];
    virtualisation.podman = {
      dockerCompat = true;
      autoPrune.enable = true;
      extraPackages = [ pkgs.zfs ];
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
    virtualisation.oci-containers = {
      backend = "podman";
    };

  };

  imports = [
    ./arr/prowlarr
    ./arr/bazarr
    ./arr/jellyseerr
    ./arr/sonarr
    ./arr/radarr
    ./arr/unpackerr
    ./arr/flaresolverr
    #./arr/lidarr
    ./audiobookrequest
    ./audiobookshelf
    ./deluge
    #./deemix
    ./homepage
    ./immich
    ./invoiceplane
    ./jellyfin
    ./keycloak
    ./microbin
    ./miniflux
    ./monitoring/grafana
    ./monitoring/prometheus
    ./monitoring/prometheus/exporters/shelly_plug_exporter
    ./navidrome
    ./nextcloud
    ./phoenix-app
    ./smarthome/homeassistant
    ./smarthome/matter-server
    ./smarthome/raspberrymatic
    ./paperless-ngx
    ./radicale
    ./sabnzbd
    ./slskd
    ./teslamate
    ./uptime-kuma
    ./vaultwarden
    ./wireguard-netns
  ];
}
