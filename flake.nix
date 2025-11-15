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
        inherit (self) outputs;
        vars = import ./vars.nix;

        nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs outputs vars; };
            
            modules = [
            # Import the previous configuration.nix we used,
            # so the old configuration file still takes effect
                ./configuration.nix
            ];
        };
    };
}