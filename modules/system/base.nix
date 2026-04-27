{ config, pkgs, ... }:

{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      substituters = [
          "https://cache.nixos.org"
          "https://beehiveserver.cachix.org"
      ];
      trusted-public-keys = [
        "beehiveserver.cachix.org-1:ZzReqkFfK1Dc+Qfrfj79EnyqiLTw5N13r/4r18aZ51c="
      ];
    };
  };

  systemd.services.zfs-mount.enable = false;

  nixpkgs.config.allowUnfree = true;

  console.keyMap = "sg";

  programs.zsh.enable = true; #TODO
  time.timeZone = "Europe/Zurich";
  zramSwap.enable = true;
  security.sudo.wheelNeedsPassword = true;

  environment.variables = { 
    EDITOR = "nano";
  };

  system.stateVersion = "25.11";
}