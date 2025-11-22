{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tailscale =
    let
      advertisedRoute =
        if lib.attrsets.hasAttrByPath [ config.networking.hostName ] config.homelab.networks.external then
          config.homelab.networks.external.${config.networking.hostName}.address
        else
          config.homelab.networks.local.lan.reservations.${config.networking.hostName}.Address;
      advertiseFlags = [
        "--advertise-routes=${advertisedRoute}/32"
        "--advertise-exit-node"
      ];
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      package = inputs.nixpkgs-unstable.legacyPackages.${system}.tailscale;
      enable = true;
      authKeyFile = config.age.secrets.tailscaleAuthKey.path;
      useRoutingFeatures = "both";
      extraSetFlags = advertiseFlags;
      extraUpFlags = advertiseFlags ++ [ "--reset" ];
    };
}
