{ ... }:

{
  imports = [
    ./base.nix
    ./users.nix
    ./packages.nix
    ./boot.nix
    ./network.nix
    ./auto-upgrade.nix
    ./zfs-mounts.nix
  ];
}