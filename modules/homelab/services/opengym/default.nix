{ config, lib, pkgs, ... }:
let
  service = "opengym";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  apiService = "${service}-api";
  apiPort = 3000;
  # Upstream's compose downloads this once into ./media; pinning it keeps the
  # images and GIFs identical across rebuilds. The media is © Gym visual and
  # used under that dataset's terms (see upstream NOTICE.md).
  exerciseMedia = pkgs.fetchFromGitHub {
    owner = "hasaneyldrm";
    repo = "exercises-dataset";
    rev = "7455efae41b330c265e7cd4b78dfa848e7ce5ebd";
    hash = "sha256-bAit6zzd1Q1SPgb3ydjuZN78yXjRcgcIs+hH4gKNaxE=";
  };
  mcp = pkgs.callPackage ./mcp.nix { };
  # Read-only MCP server for LLM clients, spawned over ssh. The data files are
  # 0600 and owned by the homelab user, so it runs as that user.
  mcpCommand = pkgs.writeShellScriptBin "opengym-mcp" ''
    exec /run/wrappers/bin/sudo -u ${homelab.user} \
      ${pkgs.coreutils}/bin/env OPENGYM_DATA=${cfg.dataDir} \
      ${mcp}/bin/opengym-mcp
  '';
in {
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Enable ${service}";
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5057;
      description = "Host port ${service} listens on.";
    };
    apiImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/duartesantos8/opengym-api:latest";
      description = "Container image for the ${service} API.";
    };
    webImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/duartesantos8/opengym-web:latest";
      description = "Container image for the ${service} web frontend.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
      description =
        "Profiles, passkeys, workouts, uploads and the session secret.";
    };
    adminUids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Profile ids (users[].id in db.json) with admin access.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "openGym";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Workout and body-weight tracker";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "mdi-dumbbell";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d ${cfg.dataDir} 0775 ${homelab.user} ${homelab.group} - -" ];

    environment.systemPackages = [ mcpCommand ];

    virtualisation.podman.enable = true;
    virtualisation.oci-containers.containers = {
      # The web container joins this one's network namespace, so the published
      # port belongs here and nginx reaches the API on 127.0.0.1.
      ${apiService} = {
        image = cfg.apiImage;
        autoStart = true;
        user = "${toString config.users.users.${homelab.user}.uid}:${
            toString config.users.groups.${homelab.group}.gid
          }";
        ports = [ "${toString cfg.port}:80" ];
        volumes = [ "${cfg.dataDir}:/data" ];
        environment = {
          PORT = toString apiPort;
          DATA_DIR = "/data";
          # Only nginx in the web container talks to the API, and it
          # overwrites the forwarded-for headers with the real peer.
          TRUST_PROXY = "1";
          RP_ID = cfg.url;
          ORIGIN = "https://${cfg.url}";
          RP_NAME = "openGym";
          ADMIN_UIDS = lib.concatStringsSep "," cfg.adminUids;
        };
        extraOptions = [ "--pull=newer" ];
      };
      ${service} = {
        image = cfg.webImage;
        autoStart = true;
        dependsOn = [ apiService ];
        volumes = [
          "${exerciseMedia}/images:/usr/share/nginx/html/img:ro"
          "${exerciseMedia}/videos:/usr/share/nginx/html/gif:ro"
        ];
        environment = {
          NGINX_PORT = "80";
          BACKEND = "127.0.0.1";
          PORT = toString apiPort;
          # BACKEND is an IP literal, so nginx never queries this resolver;
          # the template still needs a value, and Docker's default is absent.
          RESOLVER = "127.0.0.1";
        };
        extraOptions = [ "--pull=newer" "--network=container:${apiService}" ];
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
