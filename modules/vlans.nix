{ config, lib, ... }:
let
  cfg = config.routeros.vlans;
  helpers = config.routeros._lib;

  bridgeVlanType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      vlanIds = lib.mkOption {
        type = lib.types.either lib.types.int (lib.types.listOf lib.types.int);
        description = "VLAN ID(s) for this bridge VLAN entry.";
      };
      bridge = lib.mkOption {
        type = lib.types.str;
        default = "bridge";
        description = "Bridge name to apply this VLAN to.";
      };
      tagged = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Interfaces that should carry this VLAN tagged.";
      };
      untagged = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Interfaces that should carry this VLAN untagged.";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  vlanInterfaceType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      vlanId = lib.mkOption {
        type = lib.types.int;
        description = "VLAN ID for this /interface vlan entry.";
      };
      interface = lib.mkOption {
        type = lib.types.str;
        default = "bridge";
        description = "Parent interface (typically the bridge).";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      mtu = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
    };
  };

  mkBridgeVlan =
    idx: vlan:
    let
      vlanIds =
        if builtins.isList vlan.vlanIds then
          builtins.map toString vlan.vlanIds
        else
          [ (toString vlan.vlanIds) ];
      base = {
        bridge = vlan.bridge;
        vlan_ids = vlanIds;
      }
      // lib.optionalAttrs (vlan.tagged != [ ]) {
        tagged = vlan.tagged;
      }
      // lib.optionalAttrs (vlan.untagged != [ ]) {
        untagged = vlan.untagged;
      }
      // lib.optionalAttrs (vlan.comment != "") {
        comment = vlan.comment;
      };
      extras = builtins.removeAttrs vlan [
        "vlanIds"
        "bridge"
        "tagged"
        "untagged"
        "comment"
      ];
      ruleName =
        if vlan ? name then helpers.sanitizeName vlan.name else "bridge_vlan_${toString idx}";
    in
    {
      name = ruleName;
      value = base // (builtins.removeAttrs extras [ "name" ]);
    };

  mkVlanInterface =
    name: vlan:
    let
      base = {
        name = name;
        vlan_id = vlan.vlanId;
        interface = vlan.interface;
      }
      // lib.optionalAttrs (vlan.comment != "") {
        comment = vlan.comment;
      }
      // lib.optionalAttrs (vlan.mtu != null) {
        mtu = vlan.mtu;
      };
      extras = builtins.removeAttrs vlan [
        "vlanId"
        "interface"
        "comment"
        "mtu"
      ];
    in
    base // extras;
in
{
  options.routeros.vlans = {
    bridgeFiltering = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable VLAN filtering on the main bridge. When true, the bridge module's
        vlan_filtering attribute is set to true and you must declare bridge VLAN
        memberships explicitly via `bridgeVlans`.
      '';
    };

    bridgeVlans = lib.mkOption {
      type = lib.types.listOf bridgeVlanType;
      default = [ ];
      description = ''
        Bridge VLAN table entries (`/interface bridge vlan`). Required when
        `bridgeFiltering = true`. Each entry can have an optional `name` field
        for the Terraform resource id.
      '';
      example = lib.literalExpression ''
        [
          {
            name = "default_lan";
            vlanIds = 1;
            untagged = [ "bridge" "ether2" "ether3" ];
            comment = "Default LAN";
          }
          {
            name = "vlan20_aldebaran";
            vlanIds = 20;
            tagged = [ "bridge" "ether9" ];
          }
        ]
      '';
    };

    interfaces = lib.mkOption {
      type = lib.types.attrsOf vlanInterfaceType;
      default = { };
      description = ''
        Layer-3 VLAN interfaces (`/interface vlan`), keyed by interface name.
      '';
      example = lib.literalExpression ''
        {
          vlan20 = { vlanId = 20; interface = "bridge"; comment = "Aldebaran direct path"; };
        }
      '';
    };
  };

  config = {
    resource = lib.mkMerge [
      (lib.mkIf cfg.bridgeFiltering {
        routeros_interface_bridge.bridge.vlan_filtering = true;
      })
      (lib.mkIf (cfg.bridgeVlans != [ ]) {
        routeros_interface_bridge_vlan = builtins.listToAttrs (
          lib.imap0 mkBridgeVlan cfg.bridgeVlans
        );
      })
      (lib.mkIf (cfg.interfaces != { }) {
        routeros_interface_vlan = lib.mapAttrs mkVlanInterface cfg.interfaces;
      })
    ];
  };
}
