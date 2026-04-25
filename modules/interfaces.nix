{ config, lib, ... }:
let
  cfg = config.routeros.interfaces;
  lteCfg = cfg.lte;
in
{
  options.routeros.interfaces = {
    wan = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ether1" ];
      description = "WAN interfaces.";
    };

    lte = {
      enable = lib.mkEnableOption "LTE interface";

      apn = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "APN for LTE connection.";
      };

      provider = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "LTE provider name.";
      };
    };

    lists = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Additional interface list memberships beyond auto-generated WAN/LAN.";
    };

    listMembers = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = ''
        Additional `/interface list member` entries. Each entry is a freeform
        attrset with at least `interface` and `list`; optional `disabled`,
        `comment`. Optional `name` becomes the Terraform resource id.
      '';
      example = lib.literalExpression ''
        [
          { name = "l2tp_lan"; interface = "l2tp-in1"; list = "LAN"; }
          { name = "ovpn_lan"; interface = "ovpn-in1"; list = "LAN"; }
        ]
      '';
    };

    ethernet = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Per-ethernet-port configuration (`/interface ethernet set`). Keys are
        ethernet interface names (e.g. `ether2`); values are freeform attrsets
        of fields like `comment`, `mtu`, `disable_running_check`, etc.
        WAN interfaces declared via `routeros.interfaces.wan` are merged with
        these (per-port settings here override the WAN defaults).
      '';
      example = lib.literalExpression ''
        {
          ether2 = { comment = "2F D-Link"; };
          ether9 = { comment = "Aldebaran (server, 10.3.1.1)"; };
        }
      '';
    };
  };

  config = {
    resource = {
      # Ethernet interfaces: WAN-flagged ones plus any per-port ethernet config
      routeros_interface_ethernet =
        let
          wanEntries = builtins.listToAttrs (
            builtins.map (iface: {
              name = iface;
              value = {
                name = iface;
                factory_name = iface;
                comment = "WAN";
              };
            }) cfg.wan
          );
          extraEntries = lib.mapAttrs (
            ifaceName: ifaceCfg: {
              name = ifaceName;
              factory_name = ifaceName;
            }
            // ifaceCfg
          ) cfg.ethernet;
        in
        lib.recursiveUpdate wanEntries extraEntries;

      # Interface lists
      routeros_interface_list = {
        WAN = {
          name = "WAN";
          comment = "defconf";
        };
        LAN = {
          name = "LAN";
          comment = "defconf";
        };
      };

      # List members: bridge->LAN, WAN interfaces->WAN, LTE->WAN (if enabled)
      routeros_interface_list_member = {
        bridge_LAN = {
          interface = config.routeros.bridge.name;
          list = "LAN";
          comment = "defconf";
        };
      }
      // builtins.listToAttrs (
        builtins.map (iface: {
          name = "${iface}_WAN";
          value = {
            interface = iface;
            list = "WAN";
            comment = "defconf";
          };
        }) cfg.wan
      )
      // lib.optionalAttrs lteCfg.enable {
        lte1_WAN = {
          interface = "lte1";
          list = "WAN";
        };
      }
      // builtins.listToAttrs (
        lib.imap0 (
          idx: member:
          let
            ruleName =
              if member ? name then member.name else "extra_${toString idx}_${member.list}";
            attrs = builtins.removeAttrs member [ "name" ];
          in
          {
            name = ruleName;
            value = attrs;
          }
        ) cfg.listMembers
      );

      # LTE APN
      routeros_interface_lte_apn = lib.mkIf lteCfg.enable {
        default = {
          apn = lteCfg.apn;
          ip_type = "ipv4";
          ipv6_interface = "bridge";
          name = lteCfg.provider;
          use_network_apn = false;
        };
      };
    };
  };
}
