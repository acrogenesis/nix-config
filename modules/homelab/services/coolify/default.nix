{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "coolify";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  upstream = "http://localhost:${toString cfg.port}";

  # The compose file is generated from Nix so paths are always in sync with cfg.dataDir.
  # Shell-style ${VAR} references for Docker Compose are escaped with ''$ in Nix
  # indented strings so they survive into the rendered YAML unchanged.
  composeFile = pkgs.writeText "coolify-docker-compose.yml" ''
    services:
      coolify:
        image: "ghcr.io/coollabsio/coolify:latest"
        volumes:
          - ${cfg.dataDir}/ssh:/var/www/html/storage/app/ssh
          - ${cfg.dataDir}/applications:/var/www/html/storage/app/applications
          - ${cfg.dataDir}/databases:/var/www/html/storage/app/databases
          - ${cfg.dataDir}/services:/var/www/html/storage/app/services
          - ${cfg.dataDir}/backups:/var/www/html/storage/app/backups
          - ${cfg.dataDir}/weblogs:/var/www/html/storage/app/weblogs
          - ${cfg.dataDir}/webhooks-during-maintenance:/var/www/html/storage/app/webhooks-during-maintenance
          - ${cfg.dataDir}/metrics:/var/www/html/storage/app/metrics
          - ${cfg.dataDir}/logs:/var/www/html/storage/logs
          - ${cfg.environmentFile}:/var/www/html/.env
          - /var/run/docker.sock:/var/run/docker.sock
        ports:
          - "127.0.0.1:${toString cfg.port}:80"
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy
        env_file:
          - ${cfg.environmentFile}
        environment:
          APP_ENV: "production"
      postgres:
        image: "postgres:15-alpine"
        volumes:
          - coolify-db:/var/lib/postgresql/data
        environment:
          POSTGRES_USER: ''${DB_USERNAME:-coolify}
          POSTGRES_PASSWORD: ''${DB_PASSWORD}
          POSTGRES_DB: ''${DB_DATABASE:-coolify}
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U ''${DB_USERNAME:-coolify} -d ''${DB_DATABASE:-coolify}"]
          interval: 5s
          timeout: 20s
          retries: 10
      redis:
        image: "redis:7-alpine"
        command: redis-server --save "" --appendonly no --requirepass ''${REDIS_PASSWORD}
        healthcheck:
          test: ["CMD", "redis-cli", "-a", "''${REDIS_PASSWORD}", "ping"]
          interval: 5s
          timeout: 20s
          retries: 10
      realtime:
        image: "ghcr.io/coollabsio/coolify-realtime:latest"
        ports:
          - "127.0.0.1:6001:6001"
          - "127.0.0.1:6002:6002"
        env_file:
          - ${cfg.environmentFile}
        environment:
          APP_NAME: ''${APP_NAME:-Coolify}
          PUSHER_APP_ID: ''${PUSHER_APP_ID}
          PUSHER_APP_KEY: ''${PUSHER_APP_KEY}
          PUSHER_APP_SECRET: ''${PUSHER_APP_SECRET}
    volumes:
      coolify-db:
        driver: local
  '';
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Coolify - self-hosted PaaS";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/coolify";
      description = "Directory for Coolify data (SSH keys, app state, logs, etc.).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port the Coolify dashboard listens on.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "coolify.${homelab.baseDomain}";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the Coolify .env file (agenix secret).
        Must contain APP_KEY, APP_ID, DB_PASSWORD, REDIS_PASSWORD,
        PUSHER_APP_ID, PUSHER_APP_KEY, PUSHER_APP_SECRET, and related vars.
        Generate with Coolify's install script or manually with openssl.
      '';
    };

    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Coolify";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted PaaS";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "coolify.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    # Coolify requires a real Docker daemon — it mounts /var/run/docker.sock
    # and uses the Docker SDK to manage app containers.
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    # Podman's dockerCompat creates /var/run/docker.sock as a symlink to the
    # Podman socket, which conflicts with the real Docker daemon socket.
    # Disable it here; oci-containers (Home Assistant, etc.) use Podman directly
    # and do not need dockerCompat.
    virtualisation.podman.dockerCompat = lib.mkForce false;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.dataDir}/ssh 0750 root root - -"
      "d ${cfg.dataDir}/applications 0750 root root - -"
      "d ${cfg.dataDir}/databases 0750 root root - -"
      "d ${cfg.dataDir}/services 0750 root root - -"
      "d ${cfg.dataDir}/backups 0750 root root - -"
      "d ${cfg.dataDir}/weblogs 0750 root root - -"
      "d ${cfg.dataDir}/webhooks-during-maintenance 0750 root root - -"
      "d ${cfg.dataDir}/metrics 0750 root root - -"
      "d ${cfg.dataDir}/logs 0750 root root - -"
    ];

    systemd.services.coolify = {
      description = "Coolify PaaS";
      after = [
        "docker.service"
        "network-online.target"
      ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.docker}/bin/docker compose -p coolify --env-file ${cfg.environmentFile} -f ${composeFile} --project-directory ${cfg.dataDir} up -d --remove-orphans --wait";
        ExecStop = "${pkgs.docker}/bin/docker compose -p coolify --env-file ${cfg.environmentFile} -f ${composeFile} --project-directory ${cfg.dataDir} down";
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
