# AGENTS Checklist & Notes

Remember you are not connected to the homelab directly, if you need to run any commands on #duck ask me to run it for you.
Check `/nix/var/nix/profiles/default/bin/nix flake check --accept-flake-config` passes before finishing tasks.

## Documentation hygiene

- Update `README.md` whenever install steps or supported hosts change.
- Keep `docs/removed-services.md` in sync with config changes (add items when disabling, remove when re-enabling).
- Mention new secrets or hardware requirements in `nix-private/README.md`.

## Key learnings (2026-11-09)

- The old `home-assistant-libs/python-matter-server:stable` image is frozen at
  8.1.0. Duck now uses `matter-js/matterjs-server:stable`, running as the homelab
  user. Preserve and back up the existing data directory before its first-start
  migration; tmpfiles must repair the Python server's root-owned fabric files.
  Never run both controllers on the production network at the same time.
- Grimmory's MariaDB unit must finish `mariadb-upgrade` before the application
  starts. The 11.4 to 11.8 migration was checked on an isolated snapshot copy.
  OCI units explicitly set `TimeoutStartSec = 0`; use `lib.mkForce` when setting
  a finite timeout for the readiness and upgrade check.
- Duck's temporary package overrides cover stable releases ahead of the tested
  channel. Paperless needs its matching frontend, django-guardian and API docs
  assets; Prowlarr's bundled .NET tracing provider needs the UST 0 compatibility
  library. Build these packages and the full system, not just `flake check`.

## Key learnings (2026-11-06)

- Lego now spells the fixed DNS propagation wait flag
  `--dns.propagation.wait`. The old `--dns.propagation-wait` makes renewals exit
  before contacting the CA, allowing the shared wildcard certificate to expire.
- Scripted initrd is removed in Duck's nixpkgs revision. Remove
  `boot.initrd.systemd.enable` declarations while retaining the systemd initrd
  rollback service; systemd initrd is now unconditional.
- Nextcloud no longer accepts `config.adminuser` or `config.adminpassFile`.
  Existing users persist; on fresh installations, create the administrator using
  `nextcloud-occ user:add` and `nextcloud-occ group:adduser admin` (see README).
- The custom Keycloak trusted-device plugin and Shelly exporter needed refreshed
  `mvnHash` values with this nixpkgs update, with their source versions unchanged.
  `flake check` does not build these packages; validate the full Duck system too.
- Set both `services.paperless.user` and `services.paperless.group` for Duck's
  shared homelab account. The default `paperless` group is not created with a
  custom user, and the secret-key generator otherwise fails with `216/GROUP`.

## Key learnings (2026-09-13)

- Jellyfin 12 rejects legacy `encoding.xml` files with an empty
  `EncoderPreset`, then falls back to software transcoding. Duck declares NVENC
  through `services.jellyfin.hardwareAcceleration` and enables
  `forceEncodingConfig` so each start gets a schema-valid configuration.
- Duck's immutable root rollback erases `/var/cache` on every reboot. Jellyfin's
  cache therefore lives below its persistent data directory, and the one-shot
  `jellyfin-cache-migration` unit preserves an existing Native Trickplay cache
  on the first deployment. Keep that generated cache excluded from Restic.
- NixOS only adds its default Paperless user to the generated Redis instance's
  socket group. Duck runs Paperless as the shared homelab user, so the Paperless
  module must explicitly add that user to
  `config.services.redis.servers.paperless.group`; otherwise the scheduler,
  task queue, and web stack fail with `EACCES` on the Redis socket.

## Key learnings (2026-08-01)

- Questarr's Alpine image ships `7zip-bin`'s x86_64 p7zip 16.02 binary without
  its executable bit or glibc loader, and the old extractor cannot read common
  classic `.rar`/`.r00` game release sets even after those are supplied. The
  Questarr module mounts a Nix-built CLI-compatible wrapper at the path expected
  by `node-7z`: RAR extraction uses `unrar`, while other formats retain `7za`.
- Questarr 1.4.0's `hardlink` import mode calls `link(2)` on the unpacked
  directory itself instead of recursively linking its files, which fails with
  `EPERM`. Use `move` mode for auto-unpacked game imports; the unpack directory
  is temporary, so the move does not disturb Deluge's source archives.

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
- Mitigation in `modules/homelab/services/default.nix`: keep `dnsPropagationCheck = true` and set `extraLegoFlags = [ "--dns.propagation.wait" "5m" ]` for `security.acme.certs.${config.homelab.baseDomain}` so lego uses a fixed wait before validation instead of failing early on local propagation checks. This uses the current flag spelling (updated 2026-11-06).

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
