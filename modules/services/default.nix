{ ... }:

{
  imports = [
    ./ssh.nix
    ./impermanence.nix
    ./zfs.nix
    ./sops.nix
    ./k3s
  ];
}