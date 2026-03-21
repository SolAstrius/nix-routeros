{ config, lib, ... }:
let
  cfg = config.routeros.bridge;
in
{
  options.routeros.bridge = {
    enable = lib.mkEnableOption "bridge interface";

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces to add as bridge ports.";
      example = [ "ether2" "ether3" "ether4" "sfp1" ];
    };

    adminMac = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Manual admin MAC address for the bridge. If null, auto-mac is used.";
    };
  };

  config = lib.mkIf cfg.enable {
    resource = {
      routeros_interface_bridge.bridge = {
        name = "bridge";
        auto_mac = cfg.adminMac == null;
        comment = "defconf";
        port_cost_mode = "short";
      } // lib.optionalAttrs (cfg.adminMac != null) {
        admin_mac = cfg.adminMac;
      };

      routeros_interface_bridge_port = builtins.listToAttrs (
        builtins.map (iface: {
          name = iface;
          value = {
            bridge = "bridge";
            interface = iface;
            comment = "defconf";
            ingress_filtering = false;
            internal_path_cost = 10;
            path_cost = 10;
          };
        }) cfg.ports
      );
    };
  };
}
