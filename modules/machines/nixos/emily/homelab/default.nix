{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  wg = config.homelab.networks.external.spencer-wireguard;
  wgBase = lib.strings.removeSuffix ".1" wg.gateway;
  hl = config.homelab;
in
{
  services.fail2ban-cloudflare = {
    enable = enabled;
    apiKeyFile = config.age.secrets.cloudflareFirewallApiKey.path;
    zoneId = "5a125e72bca5869bfb929db157d89d96";

  };
  homelab = {
    enable = true;
    baseDomain = "rebelduck.cc";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflareDnsApiCredentials.path;
    timeZone = "America/Monterrey";
    mounts = {
      config = "/persist/opt/services";
      slow = "/mnt/mergerfs_slow";
      fast = "/mnt/cache";
      merged = "/mnt/user";
    };
    samba = {
      enable = true;
      passwordFile = config.age.secrets.sambaPassword.path;
      shares = {
        Backups = {
          path = "${hl.mounts.merged}/Backups";
        };
        Documents = {
          path = "${hl.mounts.fast}/Documents";
        };
        Media = {
          path = "${hl.mounts.merged}/Media";
        };
        Music = {
          path = "${hl.mounts.fast}/Media/Music";
        };
        Misc = {
          path = "${hl.mounts.merged}/Misc";
        };
        TimeMachine = {
          path = "${hl.mounts.fast}/TimeMachine";
          "fruit:time machine" = "yes";
        };
        # YoutubeArchive = {
        #   path = "${hl.mounts.merged}/YoutubeArchive";
        # };
        # YoutubeCurrent = {
        #   path = "${hl.mounts.fast}/YoutubeCurrent";
        # };
      };
    };
    services = {
      enable = true;
      slskd = {
        enable = true;
        environmentFile = config.age.secrets.slskdEnvironmentFile.path;
      };
      backup = {
        enable = true;
        passwordFile = config.age.secrets.resticPassword.path;
        s3.enable = true;
        s3.url = "https://s3.us-west-002.backblazeb2.com/acrogenesis-homelab";
        s3.environmentFile = config.age.secrets.resticBackblazeEnv.path;
        local.enable = true;
      };
      keycloak = {
        enable = true;
        dbPasswordFile = config.age.secrets.keycloakDbPasswordFile.path;
        cloudflared = {
          tunnelId = "a219d447-9e7d-4ff9-a066-43a5e46e38cb";
          credentialsFile = config.age.secrets.keycloakCloudflared.path;
        };
      };
      radicale = {
        enable = false;
        passwordFile = config.age.secrets.radicaleHtpasswd.path;
      };
      immich = {
        enable = true;
        mediaDir = "${hl.mounts.fast}/Media/Photos";
      };
      invoiceplane = {
        enable = false;
      };
      homepage = {
        enable = true;
        # misc = [
        #   {
        #     PiKVM =
        #       let
        #         ip = config.homelab.networks.local.lan.reservations.pikvm.Address;
        #       in
        #       {
        #         href = "https://${ip}";
        #         siteMonitor = "https://${ip}";
        #         description = "Open-source KVM solution";
        #         icon = "pikvm.png";
        #       };
        #   }
        #   {
        #     FritzBox = {
        #       href = "http://192.168.178.1";
        #       siteMonitor = "http://192.168.178.1";
        #       description = "Cable Modem WebUI";
        #       icon = "avm-fritzbox.png";
        #     };
        #   }
        # ];
      };
      jellyfin.enable = true;
      paperless = {
        enable = false;
        passwordFile = config.age.secrets.paperlessPassword.path;
      };
      sabnzbd.enable = true;
      sonarr.enable = true;
      radarr.enable = true;
      bazarr.enable = true;
      prowlarr.enable = true;
      jellyseerr = {
        enable = true;
        package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.jellyseerr;
      };
      nextcloud = {
        enable = false;
        admin = {
          username = "acrogenesis";
          passwordFile = config.age.secrets.nextcloudAdminPassword.path;
        };
        cloudflared = {
          tunnelId = "51350538-83fd-4ce4-8a8c-5f561e432c56";
          credentialsFile = config.age.secrets.nextcloudCloudflared.path;
        };
      };
      vaultwarden = {
        enable = false;
        cloudflared = {
          tunnelId = "7f2164f9-b23d-4429-bebf-06eb66e3a7fc";
          credentialsFile = config.age.secrets.vaultwardenCloudflared.path;
        };
      };
      microbin = {
        enable = false;
        cloudflared = {
          tunnelId = "07d0a879-e05b-4e20-b4f8-a300623282b9";
          credentialsFile = config.age.secrets.microbinCloudflared.path;
        };
      };
      miniflux = {
        enable = false;
        cloudflared = {
          tunnelId = "3e6b259f-ffdc-4730-bd8e-8e3c05600a28";
          credentialsFile = config.age.secrets.minifluxCloudflared.path;
        };
        adminCredentialsFile = config.age.secrets.minifluxAdminPassword.path;
      };
      navidrome = {
        enable = false;
        environmentFile = config.age.secrets.navidromeEnv.path;
        cloudflared = {
          tunnelId = "5ff1bb60-0716-4a0e-ab0d-4bc6dc1fe6fb";
          credentialsFile = config.age.secrets.navidromeCloudflared.path;
        };
      };
      audiobookshelf.enable = true;
      deluge.enable = true;
      wireguard-netns = {
        enable = false;
        configFile = config.age.secrets.wireguardCredentials.path;
        privateIP = "${wgBase}.2";
        dnsIP = wg.gateway;
      };
    };
  };
}
