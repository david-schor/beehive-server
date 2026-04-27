{ vars, ... }:

{
  networking = {
    interfaces.${vars.interface} = {
      ipv4.addresses = [{
        address = vars.serverIp;
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = vars.gatewayIp;
      interface = vars.interface;
    };
    nameservers = vars.nameservers;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 80 443 2222 6443 ];
      allowedUDPPorts = [ 53 ];
    };
    networkmanager = {
      enable = true;
      dns = "none";
    };
    useDHCP = false;
    dhcpcd.enable = false;
    hostId = vars.hostId;
    hostName = vars.hostname;
  };
}