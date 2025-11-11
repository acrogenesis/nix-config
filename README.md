# nix-config

Configuration files for my NixOS and nix-darwin machines.

Very much a work in progress.

## Services

> This section is generated automatically from the Nix configuration using GitHub Actions and [this cursed Nix script](bin/generateServicesTable.nix)

<!-- BEGIN SERVICE LIST -->
### duck
|Icon|Name|Description|Category|
|---|---|---|---|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/audiobookshelf.svg' width=32 height=32>|Audiobookshelf|Audiobook and podcast player|Media|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/bazarr.svg' width=32 height=32>|Bazarr|Subtitle manager|Arr|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/deluge.svg' width=32 height=32>|Deluge|Torrent client|Downloads|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/immich.svg' width=32 height=32>|Immich|Self-hosted photo and video management solution|Media|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/invoiceplane.svg' width=32 height=32>|InvoicePlane|Invoicing application|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyfin.svg' width=32 height=32>|Jellyfin|The Free Software Media System|Media|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyseerr.svg' width=32 height=32>|Jellyseerr|Media request and discovery manager|Arr|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/keycloak.svg' width=32 height=32>|Keycloak|Open Source Identity and Access Management|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/png/microbin.png' width=32 height=32>|Microbin|A minimal pastebin|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/miniflux-light.svg' width=32 height=32>|Miniflux|Minimalist and opinionated feed reader|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/navidrome.svg' width=32 height=32>|Navidrome|Self-hosted music streaming service|Media|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/nextcloud.svg' width=32 height=32>|Nextcloud|Enterprise File Storage and Collaboration|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/paperless.svg' width=32 height=32>|Paperless-ngx|Document management system|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/prowlarr.svg' width=32 height=32>|Prowlarr|PVR indexer|Arr|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/radarr.svg' width=32 height=32>|Radarr|Movie collection manager|Arr|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/radicale.svg' width=32 height=32>|Radicale|Free and Open-Source CalDAV and CardDAV Server|Services|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sabnzbd.svg' width=32 height=32>|SABnzbd|The free and easy binary newsreader|Downloads|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/slskd.svg' width=32 height=32>|slskd|Web-based Soulseek client|Downloads|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/sonarr.svg' width=32 height=32>|Sonarr|TV show collection manager|Arr|
|<img src='https://cdn.jsdelivr.net/gh/selfhst/icons/svg/bitwarden.svg' width=32 height=32>|Vaultwarden|Password manager|Services|


<!-- END SERVICE LIST -->

## Installation runbook (NixOS)

Create a root password using the TTY

```bash
sudo su
passwd
```

From your host, copy the public SSH key to the server

```bash
export NIXOS_HOST=192.168.2.xxx
ssh-add ~/.ssh/notthebee
ssh-copy-id -i ~/.ssh/notthebee root@$NIXOS_HOST
```

SSH into the host with agent forwarding enabled (for the secrets repo access)

```bash
ssh -A root@$NIXOS_HOST
```

Enable flakes

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Partition and mount the drives using [disko](https://github.com/nix-community/disko)

```bash
DISK='/dev/disk/by-id/ata-Samsung_SSD_870_EVO_250GB_S6PENL0T902873K'
DISK2='/dev/disk/by-id/ata-Samsung_SSD_870_EVO_250GB_S6PE58S586SAER'

curl https://raw.githubusercontent.com/notthebee/nix-config/main/disko/zfs-root/default.nix \
    -o /tmp/disko.nix
sed -i "s|to-be-filled-during-installation|$DISK|" /tmp/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- -m destroy,format,mount /tmp/disko.nix
```

- If you're using the three 16 TB Seagate data disks, make sure they are labelled **before** `nixos-install` runs:

```bash
mkfs.xfs -f -L Data1   /dev/disk/by-id/ata-ST16000NM001G-...
mkfs.xfs -f -L Data2   /dev/disk/by-id/ata-ST16000NM001G-...
mkfs.xfs -f -L Parity1 /dev/disk/by-id/ata-ST16000NM001G-...
mount /dev/disk/by-label/Data1   /mnt/data1
mount /dev/disk/by-label/Data2   /mnt/data2
mount /dev/disk/by-label/Parity1 /mnt/parity1
```

Install git

```bash
nix-env -f '<nixpkgs>' -iA git
```

Clone this repository

```bash
mkdir -p /mnt/etc/nixos
git clone https://github.com/notthebee/nix-config.git /mnt/etc/nixos
```

Put the private key into place (required for secret management)

```bash
mkdir -p /mnt/home/notthebee/.ssh
exit
scp ~/.ssh/notthebee root@$NIXOS_HOST:/mnt/home/notthebee/.ssh
ssh root@$NIXOS_HOST
chmod 700 /mnt/home/notthebee/.ssh
chmod 600 /mnt/home/notthebee/.ssh/*
```

Install the system

```bash
nixos-install \
--root "/mnt" \
--no-root-passwd \
 --flake "git+file:///mnt/etc/nixos#hostname" # duck, etc.
```

Unmount the filesystems

```bash
umount "/mnt/boot/efis/*"
umount -Rl "/mnt"
zpool export -a
```

Reboot

```bash
reboot
```

## Private secrets (`nix-private`)

This flake expects an accompanying secrets repository that provides encrypted payloads and shared network settings. A ready-made template lives in `./nix-private`.

- Copy the `nix-private` directory, update each placeholder `.age` file with real secrets (see below), and edit `nix-private/networks.nix` to match your LAN.
- Point the flake input at your local copy by setting `secrets = { url = "path:./nix-private"; flake = false; };` in `flake.nix` and refreshing the lock file with `nix flake lock --update-input secrets`.
- Keep the directory private (or push it to your own private Git remote) because it will eventually contain your credentials.
- The fast tier lives on a standalone ZFS pool named `cache` (Samsung 980 PRO NVMe) mounted at `/mnt/cache`. If you ever swap that drive, recreate/import the pool before rebooting or the `fileSystems.${hl.mounts.fast}` mount will fail.
- Time Machine backups are exported from `/mnt/mergerfs_slow/TimeMachine`, i.e. directly from the data array, so macOS sees the full capacity of the slow tier. If you ever move the share to a different mount, update the Samba share definition accordingly.

### Encrypting secrets correctly

Use the helper script to encrypt/decrypt secrets against the right key:

```bash
nix shell nixpkgs#age nixpkgs#ssh-to-age --command ./scripts/reencrypt-age-secrets.sh \
  --personal-key ~/.config/age/ssh_host_ed25519_key \
  --host-public-key ~/.config/age/ssh_host_ed25519_key.pub \
  --recipient-type ssh
```

- Add `--dry-run --yes` first to verify your key can decrypt the existing payloads.
- Drop `--dry-run` once you are ready to rewrite the `.age` files and commit/push them to `nix-private`.
