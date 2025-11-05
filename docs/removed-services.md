# Removed Optional Services

- **Borg backup to Aria** (`modules/machines/nixos/emily/backup/default.nix`)  
  Aria was removed from this fork, and the backup job pushed to `ssh://share@aria`. Bringing it back requires a new target host and the corresponding secrets (`borgBackupKey`, `borgBackupSSHKey`).

- **Keycloak**, **Nextcloud**, **Vaultwarden**, **Paperless**, **Navidrome**, **Miniflux**, **Microbin**, **Radicale**, **InvoicePlane**, **WireGuard netns**  
  These homelab services are currently disabled. Their `.age` secrets are commented out; re-enable them only after you recreate the necessary secrets and infrastructure (Cloudflare tunnels, databases, etc.).

- **Additional data drive**  
  SnapRAID is configured for two data disks plus one parity disk. `Data3` remains commented out until you install another drive.

Keep this list in sync with future removals or re-enables so it serves as a quick reference for which pieces still need secrets or hardware.
