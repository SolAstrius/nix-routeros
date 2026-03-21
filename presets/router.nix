{ config, ... }:
{
  imports = [ ../modules ];

  routeros = {
    system = {
      timezone = "UTC";

      services = let subnet = config.routeros.network.subnet; in {
        ssh = { enable = true; allowedAddresses = subnet; };
        winbox = { enable = true; allowedAddresses = subnet; };
        api = { enable = true; allowedAddresses = subnet; };
        ftp.enable = false;
        telnet.enable = false;
        www.enable = false;
        api-ssl.enable = false;
      };

      ipv6.enable = false;
      macServer.enable = true;
      neighborDiscovery.enable = true;
      bfd.enable = true;
    };

    bridge.enable = true;

    network.dhcp = {
      server.enable = true;
      client.enable = true;
    };

    dns = {
      enable = true;
      upstream = [ "8.8.8.8" "4.4.4.4" ];
      localDomain = "local";
    };

    firewall.enable = true;

    wifi.enable = false;
    interfaces.lte.enable = false;
  };
}
