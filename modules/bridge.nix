{ config, lib, ... }:
let
  cfg = config.routeros.bridge;
  # Sanitize the bridge name for use as a Terraform resource id (kebab → snake).
  bridgeRsc = config.routeros._lib.sanitizeName cfg.name;
in
{
  options.routeros.bridge = {
    enable = lib.mkEnableOption "bridge interface";

    name = lib.mkOption {
      type = lib.types.str;
      default = "bridge";
      description = ''
        Name of the bridge interface as RouterOS sees it. Defaults to "bridge"
        which matches the RouterOS factory defconf. Other modules (interface
        lists, mac-server, etc.) reference this name when wiring up the LAN.
      '';
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces to add as bridge ports.";
      example = [
        "ether2"
        "ether3"
        "ether4"
        "sfp1"
      ];
    };

    adminMac = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Manual admin MAC address for the bridge. If null, auto-mac is used.";
    };

    portDefaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Default attributes applied to every bridge port. The module deliberately
        leaves bridge-port fields unset by default (so RouterOS-side customizations
        like ingress_filtering=true survive an apply). Set this to e.g.
        `{ ingress_filtering = false; internal_path_cost = 10; path_cost = 10; }`
        if you want the upstream "defconf" RouterOS factory layout.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_interface_bridge.${bridgeRsc} = {
        name = cfg.name;
        auto_mac = cfg.adminMac == null;
        comment = "defconf";
        port_cost_mode = "short";
      }
      // lib.optionalAttrs (cfg.adminMac != null) {
        admin_mac = cfg.adminMac;
      };

      routeros_interface_bridge_port = builtins.listToAttrs (
        builtins.map (iface: {
          name = iface;
          value = {
            bridge = cfg.name;
            interface = iface;
          }
          // cfg.portDefaults;
        }) cfg.ports
      );
    };
  };
}
