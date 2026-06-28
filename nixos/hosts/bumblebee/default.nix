{ config
, lib
, pkgs
, ...
}: {
  config = {

    mySystem = {
      purpose = "Homelab";
      persistentFolder = "/persist";
      system = {
        impermanence.enable = true;
        motd.networkInterfaces = [ "enp1s0" ];
        resticBackup = {
          remote.enable = true;
          local.enable = false;
        };
      };

      services = {
        # Enable core services
        openssh.enable = true;
        podman.enable = true;

        # Enable Ingress
        nginx.enable = true;

        # Enable hosted services
        backrest.enable = true;
        gatus.enable = true;
        forgejo.enable = true;
        atlas-probe.enable = true;
        homebox.enable = true;
        towonel.enable = true;
      };

      security.acme.enable = true;
    };

    boot = {
      initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
      initrd.kernelModules = [ ];
      # kernelModules = [ "kvm-intel" ];
      extraModulePackages = [ ];
    };

    networking = {
      hostName = "bumblebee"; # Define your hostname.
      hostId = "bce6d044";
      useDHCP = lib.mkDefault true;
    };

    fileSystems = {
      "/" =
        {
          device = "rpool/local/root";
          fsType = "zfs";
        };

      "/nix" =
        {
          device = "rpool/local/nix";
          fsType = "zfs";
        };

      "/persist" =
        {
          device = "rpool/safe/persist";
          fsType = "zfs";
          neededForBoot = true; # for impermanence
        };

      "/boot" =
        {
          device = "/dev/disk/by-uuid/E6EC-784B";
          fsType = "vfat";
          options = [ "fmask=0022" "dmask=0022" ];
        };
    };

    swapDevices =
      [{ device = "/dev/disk/by-uuid/493a7dc4-c85f-4719-8100-756640d5a73a"; }];

  };
}
