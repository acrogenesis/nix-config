{
  inputs,
  lib,
  config,
  ...
}:
{
  age.secrets.gitIncludes = {
    file = "${inputs.secrets}/gitIncludes.age";
    path = "$HOME/.config/git/includes";
  };

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Adrian";
        email = "adrian@acrogenesis.com";
      };
      core.sshCommand = "ssh -o 'IdentitiesOnly=yes' -i ~/.ssh/id_ed25519";
    };
    includes = [
      {
        path = "~" + (lib.removePrefix "$HOME" config.age.secrets.gitIncludes.path);
        condition = "gitdir:~/Workspace/Projects/";
      }
    ];
  };
}
