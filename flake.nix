{
  description = "k3s cluster homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    impermanence.url = "github:nix-community/impermanence";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix, lanzaboote, impermanence, ... }:
  let
    vars = import ./vars.nix;
  in {
    nixosConfigurations = {
      beeserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit vars sops-nix lanzaboote; };
        modules = [
          ./configuration.nix
          sops-nix.nixosModules.sops
          lanzaboote.nixosModules.lanzaboote
          impermanence.nixosModules.impermanence
        ];
      };

      beeserver-iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit vars; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./modules/iso.nix
        ];
      };
    };
  };
}