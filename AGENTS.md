# AGENTS Checklist & Notes

Remember you are not connected to the homelab directly, if you need to run any commands on #duck ask me to run it for you.
Check `/nix/var/nix/profiles/default/bin/nix flake check --accept-flake-config` passes before finishing tasks.

## Documentation hygiene

- Update `README.md` whenever install steps or supported hosts change.
- Keep `docs/removed-services.md` in sync with config changes (add items when disabling, remove when re-enabling).
- Mention new secrets or hardware requirements in `nix-private/README.md`.

## Key learnings (2026-07-31)

- Questarr's GHCR `latest`, `production-sha-fcede1d`, and `v1.4.0` tags all
  reference the same OCI index, but its x86_64 child manifest is missing from
  GHCR. The identical image on Docker Hub is complete, so Duck uses
  `docker.io/doezer/questarr:latest`.

## Key learnings (2026-07-28)

- The TeslaMate input follows upstream's default branch rather than a release
  tag. `flake.lock` still freezes the deployed revision; run
  `nix flake update teslamate` to advance it.
- TeslaMate 4 drops ARMv7 support, but Duck is x86_64 and is unaffected. The
  NixOS unit runs database migrations in `ExecStartPre`; take a database backup
  before deploying a major update.
- Deluge 2.2.0 imports `pkg_resources`, which setuptools 82 removed. Duck
  overrides only Deluge's Python package set to use `setuptools_80` until
  Deluge or nixpkgs migrates away from `pkg_resources`.

## Key learnings (2026-02-09)

- On Duck, `acme-order-renew-rebelduck.cc.service` can fail DNS-01 propagation checks even when Cloudflare's API shows `_acme-challenge.rebelduck.cc` TXT records were created. During failures, authoritative queries (`hugh.ns.cloudflare.com`) and recursive lookups (`1.1.1.1`) still return "no TXT record", and renew exits status `11`.
- Mitigation in `modules/homelab/services/default.nix`: keep `dnsPropagationCheck = true` and set `extraLegoFlags = [ "--dns.propagation-wait" "5m" ]` for `security.acme.certs.${config.homelab.baseDomain}` so lego uses a fixed wait before validation instead of failing early on local propagation checks.

## Key learnings (2026-02-11)

- TeslaMate `v2.x` enforces PostgreSQL compatibility at runtime and fails startup on PostgreSQL 14 (`PostgreSQL version 14.20 is not supported. Only 16.7 and 17.3 and 18.0 are supported.`).
- Duck currently has `services.immich.database.enableVectors = true` (pgvecto-rs), and nixpkgs asserts this is incompatible with PostgreSQL 17+; PostgreSQL 16 is the safe upgrade target unless Immich is migrated off pgvecto-rs first.

## Key learnings (2025-11-10)

- hddfancontrol v2 *requires* at least one PWM path per instance in `<path>:<start>:<stop>` form. Leaving the list empty still emits `-p` without an argument, so the daemon bails out (systemd status code 2). Duck resolves the nct6775 `hwmon` index at service start because the numeric index changes across boots, and starts fan control after `systemd-modules-load.service`.
- Paperless-ngx services need explicit `RequiresMountsFor` on `/mnt/user/Documents/Paperless/{Documents,Import}` (see `modules/homelab/services/paperless-ngx/default.nix`) or systemd fails to enter the namespace with status 226 whenever those ZFS mounts lag during boot.
- `kernel.unprivileged_userns_clone=0` means systemd can't honor `PrivateUsers`. Force `PrivateUsers = false` for every Paperless unit in the same module, or the ExecStartPre wrapper exits early with 226/NAMESPACE.

## Key learnings (2025-05-08)

- Always reconcile `modules/machines/*/secrets/default.nix` with any services you disable; lingering entries force nonexistent secrets.
- SnapRAID configuration assumes distinct parity and data disks. Match the labels (`Data1`, `Data2`, `Parity1`) to real hardware to avoid evaluation failures.
- Agenix needs both a valid recipient list (`secrets.nix`) and a path to the private key (`~/.config/age/keys.txt`) before `agenix -e` works.
- Cloudflare integration involves more than DNS challenges—tunnels and fail2ban rely on additional API credentials.
- The stock disko config assumed mirrored SATA boot drives; update `zfs-root.bootDevices` and `modules/machines/nixos/duck/disko.nix` when switching to a single NVMe.

Add new dates/notes as you discover more quirks so future edits stay smooth.
