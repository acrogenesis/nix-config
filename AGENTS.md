# AGENTS Checklist & Notes

## Documentation hygiene

- Update `README.md` whenever install steps or supported hosts change.
- Keep `docs/removed-services.md` in sync with config changes (add items when disabling, remove when re-enabling).
- Mention new secrets or hardware requirements in `nix-private/README.md`.

## Key learnings (2025-05-08)

- Always reconcile `modules/machines/*/secrets/default.nix` with any services you disable; lingering entries force nonexistent secrets.
- SnapRAID configuration assumes distinct parity and data disks. Match the labels (`Data1`, `Data2`, `Parity1`) to real hardware to avoid evaluation failures.
- Agenix needs both a valid recipient list (`secrets.nix`) and a path to the private key (`~/.config/age/keys.txt`) before `agenix -e` works.
- Cloudflare integration involves more than DNS challenges—tunnels and fail2ban rely on additional API credentials.
- The stock disko config assumed mirrored SATA boot drives; update `zfs-root.bootDevices` and `modules/machines/nixos/emily/disko.nix` when switching to a single NVMe.

Add new dates/notes as you discover more quirks so future edits stay smooth.
