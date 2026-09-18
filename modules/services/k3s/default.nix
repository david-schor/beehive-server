  { ... }:

  {
    imports = [
      ./k3s.nix
      ./argo
      ./nixidy.nix

      ./caddy
      ./vaultwarden
      ./pihole
      ./arr
      ./grafana
      ./prometheus
      ./node-exporter
      ./homelable
    ];
  }