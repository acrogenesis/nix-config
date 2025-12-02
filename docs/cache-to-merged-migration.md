# Cache-to-merged migration

This runbook walks through the exact actions required to move every workload from `/mnt/cache` to the merged `/mnt/user` view, seed the slow pool with a full copy, and re-enable backups/mover without risking data loss.

## 0. Prerequisites

- Run everything from the `duck` host with root access.
- Ensure `/mnt/cache`, `/mnt/mergerfs_slow`, and `/mnt/user` are mounted: `findmnt /mnt/cache /mnt/mergerfs_slow /mnt/user`.
- Confirm restic credentials exist at `/run/secrets/restic-password` and `/run/secrets/resticBackblazeEnv`.

## 1. Quiesce services

Stop every service that reads or writes the media/config directories we are about to migrate:

```bash
sudo systemctl stop 'immich*' \
  paperless-consumer.service paperless-scheduler.service paperless-task-queue.service paperless-web.service \
  jellyfin.service sabnzbd.service sonarr.service radarr.service flaresolverr.service bazarr.service prowlarr.service jellyseerr.service \
  slskd.service navidrome.service deemix.service deluged.service audiobookshelf.service homepage-dashboard.service \
  keycloak.service grafana.service prometheus.service radicale.service mergerfs-uncache.service mover.service
# Ignore “Unit … not loaded” errors—those simply mean the service is currently disabled on this host. For timers, stop both the service and the timer (e.g., `sudo systemctl stop mergerfs-uncache.timer`).
```

Verify nothing is writing to `/mnt/cache` (pull `lsof` from nixpkgs if it isn’t installed):

```bash
nix shell nixpkgs#lsof --command sudo lsof +D /mnt/cache

# If anything is still listed (e.g. deluged), stop it explicitly:
sudo systemctl stop deluged.service
```

The command should return no processes; stop any stragglers before proceeding.

## 2. Seed the slow pool with authoritative copies

Create the target directories on the slow tier ahead of time (rsync won’t create deep directory trees when the parent doesn’t exist):

```bash
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Media/Photos
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Media/Music
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Documents/Paperless/Documents
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Documents/Paperless/Import
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Documents
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Downloads
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Downloads.tmp
sudo install -d -m 0775 -o share -g share /mnt/mergerfs_slow/Media/Books
```

Run each rsync command in order. Keep the trailing slash on the source path so only contents are copied, and include `--delete` on the final pass *after* you verify the destination.

```bash
# Immich originals
sudo rsync -aHAX --info=progress2 /mnt/cache/Media/Photos/ /mnt/mergerfs_slow/Media/Photos/

# Music libraries + staging folders (Navidrome/slskd/deemix/Jellyfin)
sudo rsync -aHAX --info=progress2 /mnt/cache/Media/Music/ /mnt/mergerfs_slow/Media/Music/

# Paperless document archive + import dropbox
sudo rsync -aHAX --info=progress2 /mnt/cache/Documents/Paperless/Documents/ /mnt/mergerfs_slow/Documents/Paperless/Documents/
sudo rsync -aHAX --info=progress2 /mnt/cache/Documents/Paperless/Import/ /mnt/mergerfs_slow/Documents/Paperless/Import/

# Generic documents share consumed by Nextcloud/Home Assistant/etc.
sudo rsync -aHAX --info=progress2 /mnt/cache/Documents/ /mnt/mergerfs_slow/Documents/

# Temp/staging areas (optional but recommended if they contain state you care about)
sudo rsync -aHAX --info=progress2 /mnt/cache/Downloads/ /mnt/mergerfs_slow/Downloads/
sudo rsync -aHAX --info=progress2 /mnt/cache/Downloads.tmp/ /mnt/mergerfs_slow/Downloads.tmp/
sudo rsync -aHAX --info=progress2 /mnt/cache/Media/Books/ /mnt/mergerfs_slow/Media/Books/
```

Validation:

```bash
sudo du -sh /mnt/cache/Media/Photos /mnt/mergerfs_slow/Media/Photos
sudo du -sh /mnt/cache/Media/Music  /mnt/mergerfs_slow/Media/Music
sudo du -sh /mnt/cache/Documents/Paperless/Documents /mnt/mergerfs_slow/Documents/Paperless/Documents
sudo du -sh /mnt/cache/Documents/Paperless/Import /mnt/mergerfs_slow/Documents/Paperless/Import
sudo du -sh /mnt/cache/Documents /mnt/mergerfs_slow/Documents
```

Each pair should have matching sizes (minor differences are expected before the final sync).

When you are satisfied, rerun the rsync commands with `--delete` appended to ensure the slow tier becomes an exact mirror:

```bash
sudo rsync -aHAX --delete /mnt/cache/Media/Photos/ /mnt/mergerfs_slow/Media/Photos/
sudo rsync -aHAX --delete /mnt/cache/Media/Music/ /mnt/mergerfs_slow/Media/Music/
sudo rsync -aHAX --delete /mnt/cache/Documents/Paperless/Documents/ /mnt/mergerfs_slow/Documents/Paperless/Documents/
sudo rsync -aHAX --delete /mnt/cache/Documents/Paperless/Import/ /mnt/mergerfs_slow/Documents/Paperless/Import/
sudo rsync -aHAX --delete /mnt/cache/Documents/ /mnt/mergerfs_slow/Documents/
sudo rsync -aHAX --delete /mnt/cache/Downloads/ /mnt/mergerfs_slow/Downloads/
sudo rsync -aHAX --delete /mnt/cache/Downloads.tmp/ /mnt/mergerfs_slow/Downloads.tmp/
sudo rsync -aHAX --delete /mnt/cache/Media/Books/ /mnt/mergerfs_slow/Media/Books/
```

## 3. Protect against accidental cache writes

Move the old cache copies out of the way but leave plain directories behind (do **not** symlink them back into `/mnt/user`, as that creates an infinite loop through mergerfs):

```bash
sudo mv /mnt/cache/Media/Photos /mnt/cache/Media/Photos.cache-pre-migration && sudo install -d -m 0775 -o share -g share /mnt/cache/Media/Photos
sudo mv /mnt/cache/Media/Music  /mnt/cache/Media/Music.cache-pre-migration  && sudo install -d -m 0775 -o share -g share /mnt/cache/Media/Music
sudo mv /mnt/cache/Documents    /mnt/cache/Documents.cache-pre-migration    && sudo install -d -m 0775 -o share -g share /mnt/cache/Documents
```

The `*.cache-pre-migration` directories hold the extra copies you just made from the NVMe; keep them around until you have at least two successful mover + restic cycles, then delete them to reclaim space.

## 4. SnapRAID safety net

Bring parity in sync with the new layout:

```bash
sudo snapraid sync
sudo snapraid status
```

No errors should be reported.

## 5. Deploy the Nix configuration

Rebuild the host with the updated flake (which points all services at `/mnt/user` and removes mover exclusions):

```bash
cd /persist/etc/nixos   # adjust if you keep the repo elsewhere on duck
sudo nixos-rebuild switch --flake .#duck
```

After the switch completes, confirm the most critical units came back:

```bash
sudo systemctl status immich-server.service paperless-web.service mergerfs-uncache.service
```

All should be `active (running)`. If anything failed because of missing directories, inspect `/var/log/messages` before continuing.

## 6. Restart services (in dependency order)

```bash
sudo systemctl start keycloak.service
sudo systemctl start grafana.service prometheus.service radicale.service homepage-dashboard.service
sudo systemctl start jellyseerr.service jellyfin.service audiobookshelf.service
sudo systemctl start sabnzbd.service radarr.service sonarr.service flaresolverr.service bazarr.service prowlarr.service
sudo systemctl start navidrome.service slskd.service deemix.service deluged.service
sudo systemctl start paperless-consumer.service paperless-scheduler.service paperless-task-queue.service paperless-web.service
sudo systemctl start 'immich*'
```

Re-check `lsof +D /mnt/cache` to ensure everything is using `/mnt/user` now (the symlinks created earlier will still show the merged path underneath, which is expected).

## 7. Run the mover manually once

```bash
sudo systemctl start mergerfs-uncache.service
sudo journalctl -u mergerfs-uncache.service -n 200 --no-pager
```

The log should show files being moved out of `/mnt/cache/...` with no “Skipping … excluded” messages. When it finishes, re-enable the weekly timer:

```bash
sudo systemctl start --now mergerfs-uncache.timer
```

## 8. Force full restic backups

Kick off both local and Backblaze jobs so the new directories are captured immediately:

```bash
sudo systemctl start restic-backups-appdata-local.service
sudo systemctl start restic-backups-appdata-s3.service
sudo systemctl start restic-backups-paperless-s3.service
```

Inspect the logs for each service (`journalctl -u restic-backups-appdata-local.service -n 100 --no-pager`) to confirm successful snapshots, then verify from restic:

```bash
sudo restic -r rest:http://localhost:8000/appdata-local-duck snapshots
sudo RESTIC_PASSWORD_FILE=/run/secrets/restic-password AWS_SHARED_CREDENTIALS_FILE=/run/secrets/resticBackblazeEnv \
  restic -r s3:https://s3.us-west-002.backblazeb2.com/acrogenesis-homelab/appdata-duck snapshots
```

You should see new snapshot IDs with timestamps corresponding to this run.

## 9. Final verification

- `df -h /mnt/cache /mnt/mergerfs_slow /mnt/user` should now show minimal usage on `/mnt/cache` and heavy usage on `/mnt/mergerfs_slow`.
- Browse Immich, Jellyfin, Paperless, Navidrome, and Samba shares to confirm libraries appear intact.
- Re-enable all restic timers:
  ```bash
  sudo systemctl start --now restic-backups-appdata-local.timer restic-backups-appdata-s3.timer restic-backups-paperless-s3.timer
  ```
- Leave the `*.cache-only` directories untouched for a few days; remove them only after at least two successful mover + restic cycles.

Following these steps ensures every byte previously stored exclusively on the NVMe now lives on the slower (and parity-protected) pool, while services transparently reference the merged `/mnt/user` paths and off-site backups contain the new data layout.
