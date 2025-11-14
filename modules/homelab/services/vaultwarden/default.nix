{ config, lib, ... }:
let
  service = "vaultwarden";
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
      default = "/var/lib/bitwarden_rs";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "pass.${homelab.baseDomain}";
    };
    aliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional hostnames that should serve Vaultwarden.";
    };
    cloudflared.credentialsFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''
        pkgs.writeText "cloudflare-credentials.json" '''
        {"AccountTag":"secret"."TunnelSecret":"secret","TunnelID":"secret"}
        '''
      '';
    };
    cloudflared.tunnelId = lib.mkOption {
      type = lib.types.str;
      example = "00000000-0000-0000-0000-000000000000";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Vaultwarden";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Password manager";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "bitwarden.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };
  config = lib.mkIf cfg.enable (
    let
      hostnames = [ cfg.url ] ++ cfg.aliases;
      upstream = "http://${config.services.${service}.config.ROCKET_ADDRESS}:${
        toString config.services.${service}.config.ROCKET_PORT
      }";
    in
    {
      services = {
        fail2ban-cloudflare = lib.mkIf config.services.fail2ban-cloudflare.enable {
          jails = {
            vaultwarden = {
              serviceName = "vaultwarden";
              failRegex = "^.*Username or password is incorrect. Try again. IP: <HOST>. Username: <F-USER>.*</F-USER>.$";
            };
          };
        };
        ${service} = {
          enable = true;
          config = {
            DOMAIN = "https://${cfg.url}";
            SIGNUPS_ALLOWED = true;
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = 8222;
            EXTENDED_LOGGING = true;
            LOG_LEVEL = "warn";
            IP_HEADER = "CF-Connecting-IP";
          };
        };
        cloudflared = {
          enable = true;
          tunnels.${cfg.cloudflared.tunnelId} = {
            credentialsFile = cfg.cloudflared.credentialsFile;
            default = "http_status:404";
            ingress = lib.genAttrs hostnames (_: {
              service = upstream;
            });
          };
        };
        caddy.virtualHosts = lib.genAttrs hostnames (_: {
          useACMEHost = homelab.baseDomain;
          extraConfig = ''
            reverse_proxy ${upstream}
          '';
        });
      };
    }
  );

}
