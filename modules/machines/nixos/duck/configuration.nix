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
  bootDeviceId = "nvme-Patriot_M.2_P300_512GB_P300WCBB24093006490";
  hardDrives = [
    "/dev/disk/by-label/Data1"
    "/dev/disk/by-label/Data2"
    "/dev/disk/by-label/Parity1"
  ];
in
{
  services.prometheus.exporters.shellyplug.targets = [ ];
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="a0:ad:9f:31:cd:70", NAME="enp9s0"
  '';
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        amdvlk
        vaapiVdpau
        libva
        rocmPackages.clr.icd
      ];
    };
  };
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
    ];
  };

  networking = {
    useDHCP = true;
    networkmanager.enable = false;
    hostName = "duck";
    nameservers = [ "1.1.1.1" "8.8.8.8" gatewayIpAddress];
    interfaces.enp9s0.ipv4.addresses = [
      {
        address = duckIpAddress;
        prefixLength = 24;
      }
    ];
    defaultGateway = {
      address = gatewayIpAddress;
      interface = "enp9s0";
    };
    hostId = "0730ae51";
    firewall = {
      enable = true;
      allowPing = true;
      trustedInterfaces = [
        "enp9s0"
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
  fileSystems."/boot/efis/${bootDeviceId}-part2".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-efi";
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
        pwmPaths = [ "/sys/class/hwmon/hwmon2/device/pwm2:50:50" ];
        extraArgs = [
          "-i 30sec"
        ];
      };
    };
  };

  virtualisation.docker.storageDriver = "overlay2";

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
    excludedPaths = [
      "Media/Music"
      "Media/Photos"
      "YoutubeCurrent"
      "Downloads.tmp"
      "Media/Kiwix"
      "Documents"
      "TimeMachine"
      ".DS_Store"
      ".cache"
    ];
  };

  services.autoaspm.enable = true;
  powerManagement.powertop.enable = true;

  environment.systemPackages = with pkgs; [
    pciutils
    glances
    hdparm
    hd-idle
    hddtemp
    smartmontools
    cpufrequtils
    powertop
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
