{
    description = "base os for k3s cluster homelab";

    inputs =  {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

        impermanence.url = "github:nix-community/impermanence";

        sops-nix = {
            url = "github:Mic92/sops-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = { 
        self, 
        nixpkgs, 
        ... 
    }@inputs: {
        vars = import ./vars.nix;

        nixosConfigurations = {
            bee-server = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    ./configuration.nix
                ];
            };

            bee-server-iso = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                    ./modules/iso.nix
                ];
            };
        };
    };
}