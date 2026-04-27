  { ... }:

  {
    imports = [
      ./k3s.nix
      ./caddy
      ./vaultwarden
      ./pihole
    ];
  }