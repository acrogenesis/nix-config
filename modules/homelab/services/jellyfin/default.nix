{ config, lib, pkgs, ... }:
let
  service = "jellyfin";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  legacyCacheDir = "/var/cache/jellyfin";
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption { description = "Enable ${service}"; };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.configDir}/cache";
      description =
        "Persistent cache directory for Jellyfin and Native Trickplay assets.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Jellyfin";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "The Free Software Media System";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
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
  };
  config = lib.mkIf cfg.enable (let upstream = "http://127.0.0.1:8096";
  in lib.mkMerge [
    {
      nixpkgs.overlays = [
        (_final: prev: {
          jellyfin-web = prev.jellyfin-web.overrideAttrs
            (_finalAttrs: _previousAttrs: {
              installPhase = ''
                runHook preInstall

                # this is the important line
                sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

                mkdir -p $out/share
                cp -a dist $out/share/jellyfin-web

                runHook postInstall
              '';
            });
        })
      ];
      users.users.${homelab.user}.extraGroups =
        lib.mkBefore [ "video" "render" ];
      systemd.tmpfiles.rules = [
        "d ${cfg.cacheDir}/mesa-shader-cache 0750 ${homelab.user} ${homelab.group} - -"
      ];
      services.${service} = {
        enable = true;
        user = homelab.user;
        group = homelab.group;
        dataDir = cfg.configDir;
        cacheDir = cfg.cacheDir;
      };
      # Preserve any Native Trickplay work produced before the cache became
      # persistent. This is a no-op after the first successful migration.
      systemd.services.jellyfin-cache-migration = {
        description = "Migrate Jellyfin's legacy Native Trickplay cache";
        before = [ "jellyfin.service" ];
        unitConfig.RequiresMountsFor = cfg.cacheDir;
        serviceConfig = {
          Type = "oneshot";
          User = homelab.user;
          Group = homelab.group;
          TimeoutStartSec = "30min";
        };
        script = ''
          legacy=${lib.escapeShellArg "${legacyCacheDir}/native-trickplay"}
          destination=${lib.escapeShellArg "${cfg.cacheDir}/native-trickplay"}
          staging=${
            lib.escapeShellArg "${cfg.cacheDir}/.native-trickplay-migration"
          }

          if [[ -d "$legacy" && ! -e "$destination" ]]; then
            echo "Migrating Native Trickplay cache to $destination"
            ${pkgs.coreutils}/bin/mkdir -p "$staging"
            ${pkgs.coreutils}/bin/cp -a --reflink=auto "$legacy"/. "$staging"/
            ${pkgs.coreutils}/bin/mv -T "$staging" "$destination"
          fi
        '';
      };
      systemd.services.jellyfin = {
        after = [ "jellyfin-cache-migration.service" ];
        requires = [ "jellyfin-cache-migration.service" ];
      };
      systemd.services.jellyfin.serviceConfig.Environment = [
        "JELLYFIN_WEB_DIR=${pkgs.jellyfin-web}/share/jellyfin-web"
        "XDG_CACHE_HOME=${cfg.cacheDir}"
        "MESA_SHADER_CACHE_DIR=${cfg.cacheDir}/mesa-shader-cache"
      ];
      systemd.services.jellyfin.serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = [
          "/dev/dri/renderD128"
          "/dev/nvidia0"
          "/dev/nvidiactl"
          "/dev/nvidia-uvm"
          "/dev/nvidia-uvm-tools"
          "/dev/nvidia-modeset"
        ];
      };
      services.caddy.virtualHosts."${cfg.url}" = {
        useACMEHost = homelab.baseDomain;
        extraConfig = ''
          reverse_proxy ${upstream}
        '';
      };
    }
    (lib.mkIf (cfg.cloudflared.credentialsFile != null
      && cfg.cloudflared.tunnelId != null) {
        services.cloudflared = {
          enable = true;
          tunnels.${cfg.cloudflared.tunnelId} = {
            credentialsFile = cfg.cloudflared.credentialsFile;
            default = "http_status:404";
            ingress."${cfg.url}".service = upstream;
          };
        };
      })
  ]);

}
