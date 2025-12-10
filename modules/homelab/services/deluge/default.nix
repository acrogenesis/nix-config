{
  config,
  lib,
  pkgs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.services.deluge;
  cacheDir = "${cfg.configDir}/.cache";
  eggCacheDir = "${cacheDir}/Python-Eggs";
  ns = hl.services.wireguard-netns.namespace;
in
{
  options.homelab.services.deluge = {
    enable = lib.mkEnableOption "Deluge torrent client (bound to a Wireguard VPN network)";
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/deluge";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "deluge.${hl.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "delugeweb"
        "deluged-proxy"
        "deluged"
      ];
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Deluge";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Torrent client";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "deluge.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd = lib.mkMerge [
      {
        tmpfiles.rules = [
          "d ${cfg.configDir} 0750 ${hl.user} ${hl.group} - -"
          "d ${cacheDir} 0750 ${hl.user} ${hl.group} - -"
          "d ${eggCacheDir} 0750 ${hl.user} ${hl.group} - -"
        ];
        # Deluge plugins try to unpack into ~/.cache by default; point them at a writable path.
        services.deluged.environment = {
          HOME = cfg.configDir;
          XDG_CACHE_HOME = cacheDir;
          PYTHON_EGG_CACHE = eggCacheDir;
        };
        services.deluge-web.environment = {
          HOME = cfg.configDir;
          XDG_CACHE_HOME = cacheDir;
          PYTHON_EGG_CACHE = eggCacheDir;
        };
      }
      (lib.mkIf hl.services.wireguard-netns.enable {
        services.deluged.bindsTo = [ "netns@${ns}.service" ];
        services.deluged.requires = [
          "network-online.target"
          "${ns}.service"
        ];
        services.deluged.serviceConfig.NetworkNamespacePath = [ "/var/run/netns/${ns}" ];
        sockets."deluged-proxy" = {
          enable = true;
          description = "Socket for Proxy to Deluge WebUI";
          listenStreams = [ "58846" ];
          wantedBy = [ "sockets.target" ];
        };
        services."deluged-proxy" = {
          enable = true;
          description = "Proxy to Deluge Daemon in Network Namespace";
          requires = [
            "deluged.service"
            "deluged-proxy.socket"
          ];
          after = [
            "deluged.service"
            "deluged-proxy.socket"
          ];
          unitConfig = {
            JoinsNamespaceOf = "deluged.service";
          };
          serviceConfig = {
            User = config.services.deluge.user;
            Group = config.services.deluge.group;
            ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:58846";
            PrivateNetwork = "yes";
          };
        };
      })
    ];
    services.deluge = {
      enable = true;
      user = hl.user;
      group = hl.group;
      web = {
        enable = true;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8112
      '';
    };
  };
}
