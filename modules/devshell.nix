{ inputs, ... }: {
  systems = [ "aarch64-darwin" ];
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem = { pkgs, ... }: {
    checks.mover-permissions = pkgs.runCommand "mover-permissions-check" {
      nativeBuildInputs = [ pkgs.python313 ];
    } ''
      export PYTHONDONTWRITEBYTECODE=1
      python ${./misc/mover}/test_permissions.py
      touch $out
    '';
    treefmt = {
      projectRootFile = "flake.nix";
      settings.global.excludes = [ "*.lock" ".gitignore" "secrets/*" ];
      programs.nixfmt = {
        enable = true;
        package = pkgs.nixfmt-classic;
      };
      programs.deadnix.enable = true;
      programs.shellcheck.enable = true;
    };
    packages.default =
      pkgs.mkShell { packages = [ pkgs.just pkgs.nh pkgs.nixos-rebuild-ng ]; };
  };
}
