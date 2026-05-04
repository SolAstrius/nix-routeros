{ config, lib, ... }:
let
  cfg = config.routeros.upnp;
in
{
  options.routeros.upnp = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether the UPnP IGD service is running.";
        };
        allowDisableExternalInterface = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether clients are allowed to ask the router to disable its
            external interface via UPnP. Almost always wants to stay false.
          '';
        };
        showDummyRule = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Workaround for clients that bail when no UPnP rule is present.
            RouterOS default is true; leave it on.
          '';
        };
        interfaces = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              interface = lib.mkOption {
                type = lib.types.str;
                description = "RouterOS interface name (e.g. \"wifi1\", \"bridge-lan\").";
              };
              type = lib.mkOption {
                type = lib.types.enum [ "external" "internal" ];
                description = "\"external\" for the WAN side, \"internal\" for LAN side.";
              };
              forcedExternalIp = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Override the external IP advertised to UPnP clients. Null
                  leaves the provider default ("0.0.0.0", meaning auto).
                '';
              };
            };
          });
          default = [ ];
          description = "Per-interface UPnP role assignments.";
        };
      };
    });
    default = null;
    description = ''
      RouterOS UPnP IGD settings (`/ip upnp` and `/ip upnp interfaces`).
      Singleton — set this attribute or leave null to leave the router's
      existing UPnP config alone.

      Note: NAT-PMP itself is not supported by RouterOS. UPnP IGD covers
      the same use case, and clients like syncthing speak both.
    '';
    example = lib.literalExpression ''
      {
        enable = true;
        interfaces = [
          { interface = "wifi1";      type = "external"; }
          { interface = "bridge-lan"; type = "internal"; }
        ];
      }
    '';
  };

  config = lib.mkIf (cfg != null) {
    resource.routeros_ip_upnp.default = {
      enabled = cfg.enable;
      allow_disable_external_interface = cfg.allowDisableExternalInterface;
      show_dummy_rule = cfg.showDummyRule;
    };

    resource.routeros_ip_upnp_interfaces = lib.listToAttrs (
      lib.imap0
        (i: iface: {
          name = "iface_${toString i}_${lib.replaceStrings [ "-" ] [ "_" ] iface.interface}";
          value = {
            interface = iface.interface;
            type = iface.type;
          } // lib.optionalAttrs (iface.forcedExternalIp != null) {
            forced_external_ip = iface.forcedExternalIp;
          };
        })
        cfg.interfaces
    );
  };
}
