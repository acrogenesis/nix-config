{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hl = config.homelab;
  lan = hl.networks.local.lan;
  duckIpAddress = lan.reservations.duck.Address;
  gatewayIpAddress = lan.cidr.v4;
  duckIpv6Address = "fd84:7b2c:3e5a:1::20";
  gatewayIpv6Address = "fd84:7b2c:3e5a:1::1";
  lanInterface = lan.interface;
  bootDeviceId = "nvme-Patriot_M.2_P300_512GB_P300WCBB24093006490";
  hardDrives = [
    "/dev/disk/by-label/Data1"
    "/dev/disk/by-label/Data2"
    "/dev/disk/by-label/Parity1"
  ];
  primaryInterface = "enp5s0";
  secondaryInterface = lanInterface;
  bridgeInterface = "br0";
  bridgeInterfaces = lib.unique [
    primaryInterface
    secondaryInterface
  ];
  duckMacAddress = lan.reservations.duck.MACAddress;
in
{
  services.prometheus.exporters.shellyplug.targets = [ ];
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="88:c9:b3:b3:4f:ab", NAME="${primaryInterface}"
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="${duckMacAddress}", NAME="${secondaryInterface}"
  '';
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };
    nvidia-container-toolkit.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        libva-vdpau-driver
        libva
        rocmPackages.clr.icd
        nvidia-vaapi-driver
      ];
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  nixpkgs.overlays = [
    (_final: prev: {
      btop = prev.btop.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
        postFixup =
          (old.postFixup or "")
          + (
            let
              extraLibs =
                lib.optionals (prev ? rocmPackages && prev.rocmPackages ? "rocm-smi") [
                  prev.rocmPackages."rocm-smi"
                ]
                ++ lib.optionals (prev.stdenv.isLinux && prev ? linuxPackages && prev.linuxPackages ? nvidia_x11) [
                  prev.linuxPackages.nvidia_x11
                ];
              extraLdPath =
                lib.makeLibraryPath extraLibs + lib.optionalString (prev.stdenv.isLinux) ":/run/opengl-driver/lib";
            in
            ''
              wrapProgram $out/bin/btop \
                --prefix LD_LIBRARY_PATH : ${extraLdPath}
            ''
          );
      });
      mstpd = prev.mstpd.overrideAttrs (old: {
        NIX_CFLAGS_COMPILE = lib.toList (old.NIX_CFLAGS_COMPILE or [ ]) ++ [
          "-Wno-error=old-style-definition"
        ];
      });
    })
  ];
  boot = {
    zfs = {
      forceImportRoot = true;
      extraPools = [ "cache" ];
    };
    kernelParams = [
      "pcie_aspm=force"
      "consoleblank=60"
      "acpi_enforce_resources=lax"
      "nvme_core.default_ps_max_latency_us=50000"
    ];
    kernelModules = [
      "kvm-amd"
      "amdgpu"
      "nct6775"
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    blacklistedKernelModules = [ "nouveau" ];
    extraModulePackages = [ config.hardware.nvidia.package ];
  };

  networking = {
    useDHCP = false;
    networkmanager.enable = false;
    hostName = "duck";
    nameservers = [
      duckIpAddress
      "1.1.1.1"
      "8.8.8.8"
      gatewayIpAddress
    ];
    bridges.${bridgeInterface} = {
      interfaces = bridgeInterfaces;
      rstp = true;
    };
    interfaces =
      lib.genAttrs bridgeInterfaces (_: {
        useDHCP = false;
      })
      // {
        ${bridgeInterface} = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = duckIpAddress;
              prefixLength = 24;
            }
          ];
          ipv6.addresses = [
            {
              address = duckIpv6Address;
              prefixLength = 64;
            }
          ];
        };
      };
    defaultGateway = {
      address = gatewayIpAddress;
      interface = bridgeInterface;
    };
    defaultGateway6 = {
      address = gatewayIpv6Address;
      interface = bridgeInterface;
    };
    hostId = "0730ae51";
    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = [
        bridgeInterface
        "tailscale0"
      ];
    };
  };
  zfs-root = {
    boot = {
      bootDevices = [ bootDeviceId ];
      immutable = true;
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "sd_mod"
        "sr_mod"
      ];
      removableEfi = true;
    };
  };
  # Ensure the ESP mount always targets the expected disk; disko uses by-partlabel
  # here, which can become ambiguous if multiple disks share the same PARTLABEL.
  fileSystems."/boot/efis/${bootDeviceId}-part2".device =
    lib.mkForce "/dev/disk/by-id/${bootDeviceId}-part2";
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ../../../misc/tailscale
    ../../../misc/zfs-root
    ../../../misc/agenix
    ./filesystems
    ./homelab
    ./secrets
  ];

  services.duckdns = {
    enable = false;
    domainsFile = config.age.secrets.duckDNSDomain.path;
    tokenFile = config.age.secrets.duckDNSToken.path;
  };

  systemd.services.hd-idle = {
    description = "External HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart =
        let
          idleTime = toString 900;
          hardDriveParameter = lib.strings.concatMapStringsSep " " (x: "-a ${x} -i ${idleTime}") hardDrives;
        in
        "${pkgs.hd-idle}/bin/hd-idle -i 0 ${hardDriveParameter}";
    };
  };

  services.hddfancontrol = {
    enable = true;
    settings = {
      harddrives = {
        disks = hardDrives;
        pwmPaths = [ "/sys/devices/platform/nct6775.656/hwmon/hwmon7/pwm2:25:25" ];
        extraArgs = [
          "-i 30sec"
        ];
      };
    };
  };

  virtualisation.docker = {
    storageDriver = "overlay2";
    enableNvidia = true;
  };

  system.autoUpgrade.enable = true;

  services.withings2intervals = {
    enable = false;
    configFile = config.age.secrets.withings2intervals.path;
    authCodeFile = config.age.secrets.withings2intervals_authcode.path;
  };

  services.mover = {
    enable = true;
    cacheArray = hl.mounts.fast;
    backingArray = hl.mounts.slow;
    user = hl.user;
    group = hl.group;
    percentageFree = 60;
  };

  services.autoaspm.enable = true;
  powerManagement.powertop.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      ncurses
      libuuid
    ];
  };

  environment.systemPackages = with pkgs; [
    pciutils
    glances
    hdparm
    hd-idle
    hddtemp
    smartmontools
    cpufrequtils
    powertop
    rocmPackages.rocm-smi
    config.hardware.nvidia.package
  ];

  # tg-notify = {
  #   enable = false;
  #   credentialsFile = config.age.secrets.tgNotifyCredentials.path;
  # };

  # services.adiosBot = {
  #   enable = false;
  #   botTokenFile = config.age.secrets.adiosBotToken.path;
  # };
}
