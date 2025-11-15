{ config, lib, pkgs, ... }:
let
  service = "audiobookshelf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "audiobooks.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Audiobookshelf";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Audiobook and podcast player";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "audiobookshelf.svg";
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
  config = lib.mkIf cfg.enable (
    let
      port = 8113;
      upstream = "http://127.0.0.1:${toString port}";
      cfEnabled = cfg.cloudflared.credentialsFile != null && cfg.cloudflared.tunnelId != null;
    in
    {
      services.${service} = {
        enable = true;
        user = homelab.user;
        group = homelab.group;
        inherit port;
      };
      services.caddy.virtualHosts."${cfg.url}" = {
        useACMEHost = homelab.baseDomain;
        extraConfig = ''
          reverse_proxy ${upstream}
        '';
      };
    }
    // lib.optionalAttrs cfEnabled {
      services.cloudflared = {
        enable = true;
        tunnels.${cfg.cloudflared.tunnelId} = {
          credentialsFile = cfg.cloudflared.credentialsFile;
          default = "http_status:404";
          ingress."${cfg.url}".service = upstream;
        };
      };
    }
  );
}
