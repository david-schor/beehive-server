{ config, pkgs, pkgs, vars, ... }:

{
    imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      inputs.sops-nix.nixosModules.sops
    ];

    boot.loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
      timeout = 10;
    };

    nixpkgs.config.allowUnfree = true;

    # Enable Flakes feature and nix cli
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
      };
    };

    users.mutableUsers = false;
    users.users.${vars.userName} = {
      isNormalUser = true;
      description = vars.userName;
      extraGroups = ["networkmanager" "wheel"];
      openssh.authorizedKeys.keys = [
        vars.sshPublicKey
      ];
      shell = pkgs.zsh;
      hashedPasswordFile = config.sops.secrets."user-password".path
    };

    # TODO sops

    services = {
      openssh = {
        enable = true;
        openFirewall = true;
        settings ={
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };
      k3s = {
        enable = true;
        role = "server";
      };
      fstrim.enable = true;
    };

    networking = {
      firewall = {
        enable = true;
        allowedTCPPorts = [ 22 80 443 6443 ];
      };
      networkmanager.enable = true;
    };

    programs.zsh.enable = true;
    time.timeZone = "Europe/Zurich";
    zramSwap.enable = true;
    security.sudo.wheelNeedsPassword = false;

    environment.systemPackages = with pkgs; [
        git
        nano
        wget
  ];

  environment.variables.EDITOR = "nano";
}