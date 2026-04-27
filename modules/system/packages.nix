{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    nano
    wget
    jq
    curl
    htop
    cachix
  ];
}