# NixOS Install Playbook (duck)

## Happy Path

1. **Boot the NixOS ISO & enable flakes**
```bash
passwd                               # set root password
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

```bash
ssh-copy-id -i ~/.ssh/id_ed25519 root@192.168.50.20
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

1. **Setup SSH**
```bash
mkdir -p /mnt/persist/ssh && chmod 700 /mnt/persist/ssh

scp ~/.config/age/ssh_host_ed25519_key root@192.168.50.20:/mnt/persist/ssh/ssh_host_ed25519_key
scp ~/.config/age/ssh_host_ed25519_key root@192.168.50.20:/root/.ssh/id_ed25519

chmod 600 ~/.ssh/id_ed25519
chmod 600 /mnt/persist/ssh/ssh_host_ed25519_key

```

1. **Clone repos directly on the installer** (requires your Git credentials)
```bash
rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
git clone https://github.com/acrogenesis/nix-config.git /mnt/etc/nixos
git config --global --add safe.directory /mnt/etc/nixos
```

```bash
scp /Users/acrogenesis/Development/nix/nix-config/secrets.nix root@192.168.50.20:/mnt/etc/nixos/secrets.nix
```

1. **Partition the Patriot NVMe boot drive**
```bash
nix run github:nix-community/disko -- \
  --flake /mnt/etc/nixos#duck \
  -m destroy,format,mount
```

## Repeat ssh and clone

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
