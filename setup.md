# NixOS Install Playbook (duck)

## Happy Path

1. **Prep on macOS**
```bash
git clone https://github.com/acrogenesis/nix-config.git
git clone git@github.com:acrogenesis/nix-private.git   # private secrets repo
```

1. **Boot the NixOS ISO & enable flakes**
```bash
passwd                               # set root password
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

1. **Label & mount the data/parity disks** (skip if already labeled)
```bash
mkfs.xfs -f -L Data1   /dev/disk/by-id/ata-ST16000NM001G-2KK103_ZL2GDWS4
mkfs.xfs -f -L Data2   /dev/disk/by-id/ata-ST16000NM001G-2KK103_ZL2GEWJL
mkfs.xfs -f -L Parity1 /dev/disk/by-id/ata-ST16000NM001G-2KK103_WL20F8FF

mkdir -p /mnt/data1 /mnt/data2 /mnt/parity1
mount /dev/disk/by-label/Data1   /mnt/data1
mount /dev/disk/by-label/Data2   /mnt/data2
mount /dev/disk/by-label/Parity1 /mnt/parity1
```

1. **Partition the Patriot NVMe boot drive**
```bash
cat >/tmp/disko.nix <<'DISKO'
{ disko.devices = {
    disk.nvme = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_512GB_P300WCBB24093006490";
      content = {
        type = "gpt";
        partitions.efi = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot/efi";
          };
        };
        partitions.bpool = {
          size = "4G";
          content = { type = "zfs"; pool = "bpool"; };
        };
        partitions.rpool = {
          end = "-1M";
          content = { type = "zfs"; pool = "rpool"; };
        };
      };
    };
    zpool = {
      bpool = {
        type = "zpool";
        options = { ashift = "12"; autotrim = "on"; compatibility = "grub2"; };
        rootFsOptions = {
          acltype = "posixacl";
          canmount = "off";
          compression = "lz4";
          relatime = "on";
          xattr = "sa";
          "com.sun:auto-snapshot" = "false";
        };
        datasets."nixos/root" = { type = "zfs_fs"; mountpoint = "/boot"; };
      };
      rpool = {
        type = "zpool";
        options = { ashift = "12"; autotrim = "on"; };
        rootFsOptions = {
          acltype = "posixacl";
          canmount = "off";
          compression = "zstd";
          relatime = "on";
          xattr = "sa";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          "nixos/root"    = { type = "zfs_fs"; mountpoint = "/"; };
          "nixos/home"    = { type = "zfs_fs"; mountpoint = "/home"; };
          "nixos/var/log" = { type = "zfs_fs"; mountpoint = "/var/log"; };
          "nixos/var/lib" = { type = "zfs_fs"; mountpoint = "/var/lib"; };
          "nixos/persist" = { type = "zfs_fs"; mountpoint = "/persist"; };
          "nixos/nix"     = { type = "zfs_fs"; mountpoint = "/nix"; };
        };
      };
    };
  };
}
DISKO

```bash
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  -m destroy,format,mount /tmp/disko.nix
```

5. **Setup SSH
```bash
vim ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

```bash
mkdir -p /mnt/persist/ssh && chmod 700 /mnt/persist/ssh
```

```bash
# on mac
scp ~/.config/age/ssh_host_ed25519_key root@192.168.50.125:/mnt/persist/ssh/ssh_host_ed25519_key

# copy the public key (optional but nice to have)
scp ~/.config/age/ssh_host_ed25519_key.pub root@192.168.50.125:/mnt/persist/ssh/ssh_host_ed25519_key.pub

# lock down permissions on the installer
chmod 600 /mnt/persist/ssh/ssh_host_ed25519_key
```

6. **Clone repos directly on the installer** (requires your Git credentials)
```bash
mkdir -p /mnt/etc/nixos
git clone https://github.com/acrogenesis/nix-config.git /mnt/etc/nixos
# git clone git@github.com:acrogenesis/nix-private.git /mnt/etc/nixos/nix-private

git config --global --add safe.directory /mnt/etc/nixos
```

1. **Install**
```bash
nixos-install \
--root "/mnt" \
--no-root-passwd \
--flake "git+file:///mnt/etc/nixos#duck"
```

1. **After reboot**
```bash
sudo snapraid touch
sudo snapraid sync
sudo nixos-rebuild switch --flake /etc/nixos#duck   # when enabling services (slskd, fail2ban, etc.)
```

## Troubleshooting
- **Secrets missing**: keep `secrets = { url = "git+ssh://git@github.com/acrogenesis/nix-private.git"; flake = false; }` and ensure the installer has your SSH key.
- **Git unsafe repo**: `chown -R root:root /mnt/etc/nixos` and `git config --global --add safe.directory /mnt/etc/nixos`.
- **`slskd` type error**: temporarily set `homelab.services.slskd.enable = false;` during install; re-enable after boot once `slskdEnvironmentFile.age` exists.
- **Tmpfs full** (`No space left`): remove `/root/nix-config` or run `TMPDIR=/mnt/tmp nixos-install …` to spill to the target disk.
