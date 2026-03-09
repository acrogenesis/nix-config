{ lib, ... }:
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

    settings = {
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];
      download-buffer-size = 128 * 1024 * 1024;
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
}
