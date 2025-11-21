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
        "render"
      ];
      group = "acrogenesis";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiBWISainNZ2z111xO8t65x6LcMeP67BCtn1/OhvmsV adrian.rangel@gmail.com"
      ];
    };
    groups.acrogenesis.gid = 1000;
  };

  programs.zsh.enable = true;
}
