{
  pkgs,
  ...
}:
{
  nix.settings.trusted-users = [ "acrogenesis" ];

  users = {
    users.acrogenesis = {
      shell = pkgs.zsh;
      uid = 1000;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "users"
        "video"
        "podman"
        "input"
      ];
      group = "acrogenesis";
      openssh.authorizedKeys.keys = [ ];
    };
    groups.acrogenesis.gid = 1000;
  };

  programs.zsh.enable = true;
}
