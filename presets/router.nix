{ config, lib, ... }:
{
  imports = [ ../modules ];

  routeros = {
    system = {
      timezone = lib.mkDefault "UTC";

      services = let subnet = config.routeros.network.subnet; in {
        ssh = { enable = lib.mkDefault true; allowedAddresses = lib.mkDefault subnet; };
        winbox = { enable = lib.mkDefault true; allowedAddresses = lib.mkDefault subnet; };
        api = { enable = lib.mkDefault true; allowedAddresses = lib.mkDefault subnet; };
        ftp.enable = lib.mkDefault false;
        telnet.enable = lib.mkDefault false;
        www.enable = lib.mkDefault false;
        api-ssl.enable = lib.mkDefault false;
      };

      ipv6.enable = lib.mkDefault false;
      macServer.enable = lib.mkDefault true;
      neighborDiscovery.enable = lib.mkDefault true;
      bfd.enable = lib.mkDefault true;
    };

    bridge.enable = lib.mkDefault true;

    network.dhcp = {
      server.enable = lib.mkDefault true;
      client.enable = lib.mkDefault true;
    };

    dns = {
      enable = lib.mkDefault true;
      upstream = lib.mkDefault [ "8.8.8.8" "4.4.4.4" ];
      localDomain = lib.mkDefault "local";
    };

    firewall.enable = lib.mkDefault true;

    wifi.enable = lib.mkDefault false;
    interfaces.lte.enable = lib.mkDefault false;
  };
}
