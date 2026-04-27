{ vars, lib, ... }:

{
  boot = {
    supportedFilesystems = [ "zfs" ];
    kernelParams = [ "ip=${vars.serverIp}::${vars.gatewayIp}:255.255.255.0:${vars.hostname}:${vars.interface}:none::" ];
    kernelModules = [ vars.ethKernerDriver ];
    initrd.kernelModules = [ vars.ethKernerDriver ];
    zfs = {
      extraPools = [ "rpool" ];
      requestEncryptionCredentials = true;
    };
    # https://wiki.nixos.org/wiki/ZFS#Unlock_encrypted_ZFS_via_SSH_on_boot
    initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = [ /nix/secret/initrd/ssh_host_ed25519_key ];
        authorizedKeys = [ vars.sshPublicKeyPersonal ];
      };
    };
    loader.systemd-boot.enable = lib.mkForce false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      autoGenerateKeys.enable = true;
      autoEnrollKeys = {
        enable = true;
        # Automatically reboot to enroll the keys in the firmware
        autoReboot = true;
      };
    };
  };
}