{ ... }:

{
  imports = [
    ./ssh.nix
    ./impermanence.nix
    ./zfs.nix
    ./sops.nix
    ./sanoid.nix
    ./syncoid.nix
    ./k3s
  ];
}