{ config, lib, ... }:
let
  cfg = config.routeros.network.dhcp;
  connCfg = config.routeros.connection;
  netCfg = config.routeros.network;
  hosts = config.routeros.hosts;
  helpers = config.routeros._lib;
  wanInterfaces = config.routeros.interfaces.wan;
in
{
  # Note: routeros.network.subnet is declared in modules/default.nix (shared option)
  options.routeros.network = {
    dhcp = {
      server = {
        enable = lib.mkEnableOption "DHCP server";

        range = lib.mkOption {
          type = lib.types.str;
          description = "DHCP address pool range (e.g. 10.0.0.50-10.0.0.250).";
        };

        leaseTime = lib.mkOption {
          type = lib.types.str;
          default = "1d";
          description = "DHCP lease duration.";
        };
      };

      client = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable DHCP client on WAN interface for upstream connectivity.";
        };

        interface = lib.mkOption {
          type = lib.types.str;
          default = builtins.elemAt wanInterfaces 0;
          defaultText = "First WAN interface";
          description = "Interface for DHCP client.";
        };
      };
    };
  };

  config = {
    resource = lib.mkMerge [
      # DHCP server
      (lib.mkIf cfg.server.enable {
        routeros_ip_pool.dhcp = {
          name = "dhcp";
          ranges = [ cfg.server.range ];
        };

        routeros_ip_dhcp_server.defconf = {
          name = "defconf";
          address_pool = "dhcp";
          interface = "bridge";
          lease_time = cfg.server.leaseTime;
          dynamic_lease_identifiers = "client-mac,client-id";
        };

        routeros_ip_dhcp_server_network.defconf = {
          address = netCfg.subnet;
          gateway = connCfg.gateway;
          dns_server = [ connCfg.gateway ];
          netmask = toString (helpers.prefixLength netCfg.subnet);
          comment = "defconf";
        };

        # Static leases from hosts
        routeros_ip_dhcp_server_lease = builtins.listToAttrs (
          lib.mapAttrsToList (name: host: {
            name = helpers.sanitizeName name;
            value = {
              address = host.ip;
              mac_address = lib.toUpper host.mac;
              comment = if host.comment != "" then host.comment else name;
              server = "defconf";
            };
          }) (lib.filterAttrs (_: host: host.dhcp) hosts)
        );
      })

      # DHCP client on WAN
      (lib.mkIf cfg.client.enable {
        routeros_ip_dhcp_client.${cfg.client.interface} = {
          interface = cfg.client.interface;
          comment = "defconf";
        };
      })
    ];
  };
}
