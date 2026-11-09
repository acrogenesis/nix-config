{ paperless-ngx, fetchFromGitHub, fetchurl, runCommand, gnutar, xz, ... }:
let
  version = "3.4.2";
  release = fetchurl {
    url =
      "https://github.com/paperless-ngx/paperless-ngx/releases/download/v${version}/paperless-ngx-v${version}.tar.xz";
    hash = "sha256-WZvoLNj8GEQ2t1f5sZMQH7cakL8PrPVpXc2kMVL//IU=";
  };
  # Use the matching upstream release UI while nixpkgs still packages 3.3.4.
  # The backend and its Python dependencies retain their Nix build checks.
  frontend = runCommand "paperless-ngx-frontend-${version}" {
    nativeBuildInputs = [ gnutar xz ];
  } ''
    mkdir -p $out/lib/paperless-ui
    tar -xJf ${release} --strip-components=4 -C $out/lib/paperless-ui \
      paperless-ngx/src/documents/static/frontend
  '';
  package = paperless-ngx.override {
    extraPythonPackageOverrides = _final: prev: {
      django-guardian = prev.django-guardian.overridePythonAttrs (old: {
        version = "3.5.2";
        src = fetchurl {
          url =
            "https://files.pythonhosted.org/packages/84/ed/d31c3befa315d8cf52efea39078ab4871b866f03dddfa01f2ab630a8182d/django_guardian-3.5.2.tar.gz";
          hash = "sha256-yhS3ycw3vIUvN0n4qZinbP0Ou9ZqyFcm7zMSiacS04k=";
        };
        meta = old.meta // {
          changelog =
            "https://github.com/django-guardian/django-guardian/releases/tag/3.5.2";
        };
      });
      drf-spectacular-sidecar =
        prev.drf-spectacular-sidecar.overridePythonAttrs {
          version = "2026.10.1";
          src = fetchurl {
            url =
              "https://files.pythonhosted.org/packages/23/7f/e95c51746e66cae4b6ca35912ad2a211dee979647e9fce4f3b5aca780630/drf_spectacular_sidecar-2026.10.1.tar.gz";
            hash = "sha256-7I0gsllOihDr8i5bq2LsMTx8+Hk3U6BQKQsgnhboHJw=";
          };
        };
    };
  };
in package.overridePythonAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "paperless-ngx";
    repo = "paperless-ngx";
    tag = "v${version}";
    hash = "sha256-ODKumKcCaV2aljZhgdAQcWqw8qoG8uqaaP55gQ6Dfzw=";
  };
  passthru = old.passthru // { inherit frontend; };
})
