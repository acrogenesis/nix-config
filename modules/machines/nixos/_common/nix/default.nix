{ lib, ... }:
let
  readarrFaustviiPath = ../../../../.. + "/pkgs/readarr-faustvii";
in
{
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };

    settings.experimental-features = lib.mkDefault [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
    overlays = [
      (_final: prev: {
        readarr-faustvii =
          if prev.stdenv.hostPlatform.system == "x86_64-linux" then
            prev.callPackage readarrFaustviiPath { }
          else
            prev.readarr;
      })
    ];
  };
}
