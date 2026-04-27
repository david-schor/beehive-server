{ config, pkgs, vars, inputs, ... }:

{
  imports = [
    ./modules/services
    ./modules/system
  ];
}