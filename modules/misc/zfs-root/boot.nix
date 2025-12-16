{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.zfs-root.boot;
  immutableRootSnapshotScript = ''
    if ${pkgs.zfs}/bin/zfs list -H rpool/nixos/empty >/dev/null 2>&1; then
      start="rpool/nixos/empty@start"
      tmp="$start.tmp"
      old="$start.old"

      ${pkgs.zfs}/bin/zfs destroy -r "$tmp" >/dev/null 2>&1 || true
      ${pkgs.zfs}/bin/zfs destroy -r "$old" >/dev/null 2>&1 || true

      if ${pkgs.zfs}/bin/zfs snapshot -r "$tmp" >/dev/null 2>&1; then
        if ${pkgs.zfs}/bin/zfs list -H "$start" >/dev/null 2>&1; then
          ${pkgs.zfs}/bin/zfs rename -r "$start" "$old" >/dev/null 2>&1 || true
        fi

        if ${pkgs.zfs}/bin/zfs rename -r "$tmp" "$start" >/dev/null 2>&1; then
          ${pkgs.zfs}/bin/zfs destroy -r "$old" >/dev/null 2>&1 || true
        else
          if ${pkgs.zfs}/bin/zfs list -H "$old" >/dev/null 2>&1; then
            ${pkgs.zfs}/bin/zfs rename -r "$old" "$start" >/dev/null 2>&1 || true
          fi
          ${pkgs.zfs}/bin/zfs destroy -r "$tmp" >/dev/null 2>&1 || true
        fi
      fi
    fi
  '';
in
{
  options.zfs-root.boot = {
    enable = lib.mkOption {
      description = "Enable root on ZFS support";
      type = lib.types.bool;
      default = true;
    };
    devNodes = lib.mkOption {
      description = "Specify where to discover ZFS pools";
      type = lib.types.str;
      apply =
        x:
        assert (lib.strings.hasSuffix "/" x || abort "devNodes '${x}' must have trailing slash!");
        x;
      default = "/dev/disk/by-id/";
    };
    bootDevices = lib.mkOption {
      description = "Specify boot devices";
      type = lib.types.nonEmptyListOf lib.types.str;
    };
    availableKernelModules = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      default = [
        "uas"
        "nvme"
        "ahci"
      ];
    };
    immutable = lib.mkOption {
      description = "Enable root on ZFS immutable root support";
      type = lib.types.bool;
      default = true;
    };
    removableEfi = lib.mkOption {
      description = "install bootloader to fallback location";
      type = lib.types.bool;
      default = true;
    };
    partitionScheme = lib.mkOption {
      default = {
        biosBoot = "-part4";
        efiBoot = "-part2";
        bootPool = "-part1";
        rootPool = "-part3";
      };
      description = "Describe on disk partitions";
      type = lib.types.attrsOf lib.types.str;
    };
  };
  config = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      (lib.mkIf (!cfg.immutable) {
        zfs-root.fileSystems.datasets = {
          "rpool/nixos/root" = "/";
        };
      })
      (lib.mkIf cfg.immutable {
        zfs-root.fileSystems = {
          datasets = {
            "rpool/nixos/empty" = "/";
          };
        };
        boot.initrd.systemd = {
          enable = true;
          services.initrd-rollback-root = {
            after = [ "zfs-import-rpool.service" ];
            wantedBy = [ "initrd.target" ];
            before = [
              "sysroot.mount"
            ];
            path = [ pkgs.zfs ];
            description = "Rollback root fs";
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = ''
              if zfs list -H rpool/nixos/empty@start >/dev/null 2>&1; then
                zfs rollback -r rpool/nixos/empty@start && echo '  >> >> rollback complete << <<'
              else
                echo '  >> >> rollback snapshot missing; skipping << <<'
              fi
            '';
          };
        };
        system.activationScripts.immutableRootSnapshot = immutableRootSnapshotScript;
        systemd.services.immutable-root-snapshot = {
          description = "Refresh immutable root rollback snapshot";
          after = [ "local-fs.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = immutableRootSnapshotScript;
        };
      })
      {
        zfs-root.fileSystems = {
          efiSystemPartitions = (map (diskName: diskName + cfg.partitionScheme.efiBoot) cfg.bootDevices);
          datasets = {
            "bpool/nixos/root" = "/boot";
            "rpool/nixos/config" = "/etc/nixos";
            "rpool/nixos/nix" = "/nix";
            "rpool/nixos/home" = "/home";
            "rpool/nixos/persist" = "/persist";
            "rpool/nixos/var/log" = "/var/log";
            "rpool/nixos/var/lib" = "/var/lib";
          };
        };
        boot = {
          initrd.availableKernelModules = cfg.availableKernelModules;
          supportedFilesystems = [ "zfs" ];
          zfs = {
            devNodes = cfg.devNodes;
            forceImportRoot = lib.mkDefault false;
            extraPools = lib.mkBefore [ "bpool" ];
          };
          loader = {
            efi = {
              canTouchEfiVariables = (if cfg.removableEfi then false else true);
              efiSysMountPoint = ("/boot/efis/" + (builtins.head cfg.bootDevices) + cfg.partitionScheme.efiBoot);
            };
            generationsDir.copyKernels = true;
            grub = {
              enable = true;
              forceInstall = lib.mkIf cfg.removableEfi (lib.mkDefault true);
              mirroredBoots = map (diskName: {
                devices = [ "nodev" ];
                path = "/boot/efis/${diskName}${cfg.partitionScheme.efiBoot}";
              }) cfg.bootDevices;
              efiInstallAsRemovable = cfg.removableEfi;
              copyKernels = true;
              efiSupport = true;
              zfsSupport = true;
            }
            // (
              if (builtins.lessThan 2 (builtins.length cfg.bootDevices)) then
                {
                  mirroredBoots = map (diskName: {
                    devices = [ "nodev" ];
                    path = "/boot/efis/${diskName}${cfg.partitionScheme.efiBoot}";
                  }) cfg.bootDevices;
                  extraInstallCommands = (
                    toString (
                      map (diskName: ''
                        set -x
                        ${pkgs.coreutils-full}/bin/cp -r ${config.boot.loader.efi.efiSysMountPoint}/EFI /boot/efis/${diskName}${cfg.partitionScheme.efiBoot}
                        set +x
                      '') (builtins.tail cfg.bootDevices)
                    )
                  );
                }
              else
                { device = "nodev"; }
            );
          };
        };
        system.activationScripts.grubenv-reset = lib.mkIf config.boot.loader.grub.enable ''
          if [ -e /boot/grub/grubenv ]; then
            ${pkgs.grub2}/bin/grub-editenv /boot/grub/grubenv unset saved_entry >/dev/null 2>&1 || true
            ${pkgs.grub2}/bin/grub-editenv /boot/grub/grubenv unset next_entry >/dev/null 2>&1 || true
          fi
        '';
      }
    ]
  );
}
