{
  inputs,
  lib,
  config,
  options,
  ...
}:
{
  age.secrets.gitIncludes = {
    file = "${inputs.secrets}/gitIncludes.age";
    path = "$HOME/.config/git/includes";
  };

  programs.git =
    let
      hasSettings = options.programs.git ? settings;
      userBlock =
        if hasSettings then
          {
            settings = {
              user = {
                name = "Adrian";
                email = "adrian@acrogenesis.com";
              };
              core.sshCommand = "ssh -o 'IdentitiesOnly=yes' -i ~/.ssh/id_ed25519";
            };
          }
        else
          {
            userName = "Adrian";
            userEmail = "adrian@acrogenesis.com";
            extraConfig.core.sshCommand = "ssh -o 'IdentitiesOnly=yes' -i ~/.ssh/id_ed25519";
          };
    in
    userBlock
    // {
      enable = true;
      includes = [
        {
          path = "~" + (lib.removePrefix "$HOME" config.age.secrets.gitIncludes.path);
          condition = "gitdir:~/Workspace/Projects/";
        }
      ];
    };
}
