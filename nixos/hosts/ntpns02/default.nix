# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ config
, lib
, pkgs
, ...
}: {
  imports = [
    ../../modules/nixos/hardware/u-boot/ignore_boot_interrupts.nix
  ];

  mySystem.services = {

    openssh.enable = true;
    adguardhome.enable = true;
    adguard-exporter.enable = true;

    gps.enable = true;
    gpsd-exporter.enable = true;
    chrony.enable = true;
    chrony-exporter.enable = true;
  };

  hardware.raspberry-pi."4".i2c1.enable = true;
  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;

  # no mutable state I care about
  mySystem.system.resticBackup =
    {
      local.enable = false;
      remote.enable = false;
    };

  networking.hostName = "ntpns02"; # Define your hostname.
  networking.useDHCP = false;

  networking = {
    interfaces = {
      end0 = {
        ipv4.addresses = [{
          address = "172.16.20.12";
          prefixLength = 24;
        }];
        ipv6.addresses = [{
          address = "2a02:a469:59e0:20::12";
          prefixLength = 64;
        }];
      };
    };
    defaultGateway = "172.16.20.254";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "end0";
    };
    nameservers = [ "2a02:a469:59e0:20::11" "2a02:a469:59e0:20::12" "172.16.20.11" "172.16.20.12" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/7a68a300-b869-4958-8571-f98210b3ec89";
      fsType = "ext4";
      options = [ "relatime" ];
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "relatime" ];
    };
  };

  swapDevices = [ ];
}
