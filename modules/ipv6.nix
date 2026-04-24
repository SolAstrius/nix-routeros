{ config, lib, ... }:
let
  cfg = config.routeros.ipv6;
  helpers = config.routeros._lib;

  mkIndexed =
    prefix: list:
    builtins.listToAttrs (
      lib.imap0 (
        idx: item:
        let
          ruleName =
            if item ? name then helpers.sanitizeName item.name else "${prefix}_${toString idx}";
          attrs = builtins.removeAttrs item [ "name" ];
        in
        {
          name = ruleName;
          value = attrs;
        }
      ) list
    );
in
{
  options.routeros.ipv6 = {
    enable = lib.mkEnableOption "advanced IPv6 configuration (addresses, ND, firewall, NAT66)";

    addresses = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "IPv6 addresses (`/ipv6 address`). Freeform attrsets, optional `name`.";
    };

    pools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "IPv6 pools (`/ipv6 pool`), keyed by pool name.";
      example = lib.literalExpression ''
        {
          pool-lan = {
            prefix = "2a05:f480:2400:1cf7:3:0:100:0/104";
            prefix_length = 128;
          };
        }
      '';
    };

    dhcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "IPv6 DHCP servers (`/ipv6 dhcp-server`), keyed by server name.";
    };

    dhcpClients = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "IPv6 DHCP clients (`/ipv6 dhcp-client`), keyed by interface.";
    };

    nd = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "IPv6 ND configurations (`/ipv6 nd`).";
    };

    ndPrefixes = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "IPv6 ND prefixes (`/ipv6 nd prefix`).";
    };

    addressLists = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.listOf (lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything))
      );
      default = { };
      description = ''
        IPv6 firewall address lists. Keys are list names; values are lists of either
        plain address strings or attrsets `{ address = "..."; comment = "..."; }`.
      '';
      example = lib.literalExpression ''
        {
          mesh-sources = [
            { address = "2a05:f480:2400::/48"; comment = "Vultr mesh"; }
            { address = "2a01:4f9:2a:1324::/64"; comment = "Hetzner"; }
          ];
        }
      '';
    };

    firewall = {
      filterRules = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "IPv6 firewall filter rules.";
      };
      natRules = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "IPv6 firewall NAT rules.";
      };
      mangleRules = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "IPv6 firewall mangle rules.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    resource = lib.mkMerge [
      (lib.mkIf (cfg.addresses != [ ]) {
        routeros_ipv6_address = mkIndexed "addr" cfg.addresses;
      })
      (lib.mkIf (cfg.pools != { }) {
        routeros_ipv6_pool = lib.mapAttrs (n: v: { name = n; } // v) cfg.pools;
      })
      (lib.mkIf (cfg.dhcpServers != { }) {
        routeros_ipv6_dhcp_server = lib.mapAttrs (n: v: { name = n; } // v) cfg.dhcpServers;
      })
      (lib.mkIf (cfg.dhcpClients != { }) {
        routeros_ipv6_dhcp_client = lib.mapAttrs (
          ifaceName: v: { interface = ifaceName; } // v
        ) cfg.dhcpClients;
      })
      (lib.mkIf (cfg.nd != [ ]) {
        routeros_ipv6_neighbor_discovery = mkIndexed "nd" cfg.nd;
      })
      (lib.mkIf (cfg.ndPrefixes != [ ]) {
        routeros_ipv6_nd_prefix = mkIndexed "ndprefix" cfg.ndPrefixes;
      })
      (lib.mkIf (cfg.addressLists != { }) {
        routeros_ipv6_firewall_addr_list = builtins.listToAttrs (
          lib.concatLists (
            lib.mapAttrsToList (
              listName: addresses:
              lib.imap0 (
                idx: addr:
                let
                  entry = if builtins.isAttrs addr then addr else { address = addr; };
                in
                {
                  name = "${helpers.sanitizeName listName}_${toString idx}";
                  value = entry // { list = listName; };
                }
              ) addresses
            ) cfg.addressLists
          )
        );
      })
      (lib.mkIf (cfg.firewall.filterRules != [ ]) {
        routeros_ipv6_firewall_filter = mkIndexed "v6filter" cfg.firewall.filterRules;
      })
      (lib.mkIf (cfg.firewall.natRules != [ ]) {
        routeros_ipv6_firewall_nat = mkIndexed "v6nat" cfg.firewall.natRules;
      })
      (lib.mkIf (cfg.firewall.mangleRules != [ ]) {
        routeros_ipv6_firewall_mangle = mkIndexed "v6mangle" cfg.firewall.mangleRules;
      })
    ];
  };
}
