{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "jellyfin";
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
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (_final: prev: {
        jellyfin-web = prev.jellyfin-web.overrideAttrs (
          _finalAttrs: _previousAttrs: {
            installPhase = ''
              runHook preInstall

              # this is the important line
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web

              runHook postInstall
            '';
          }
        );
      })
    ];
    users.users.${homelab.user}.extraGroups = lib.mkBefore [
      "video"
      "render"
    ];
    systemd.tmpfiles.rules = [
      "d /var/cache/jellyfin 0750 ${homelab.user} ${homelab.group} - -"
      "d /var/cache/jellyfin/mesa-shader-cache 0750 ${homelab.user} ${homelab.group} - -"
    ];
    services.${service} = {
      enable = true;
      user = homelab.user;
      group = homelab.group;
      dataDir = cfg.configDir;
    };
    systemd.services.jellyfin.serviceConfig.Environment = [
      "JELLYFIN_WEB_DIR=${pkgs.jellyfin-web}/share/jellyfin-web"
      # Force VA-API to use the AMD iGPU and keep shader caches off /var/empty.
      "LIBVA_DRIVER_NAME=radeonsi"
      "VDPAU_DRIVER=radeonsi"
      "XDG_CACHE_HOME=/var/cache/jellyfin"
      "MESA_SHADER_CACHE_DIR=/var/cache/jellyfin/mesa-shader-cache"
      "VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
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
        reverse_proxy http://127.0.0.1:8096
      '';
    };
  };

}
