{ config, lib, ... }:
let
  cfg = config.routeros.sniffer;
in
{
  options.routeros.sniffer = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      freeformType = lib.types.attrsOf lib.types.anything;
      options = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the sniffer is actively running.";
        };
        filterInterface = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Interfaces to capture from. Empty list means all.";
        };
        filterIpAddress = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            IPv4 addresses to filter on (no /CIDR — provider rejects masks).
            Use bare addresses like "185.9.72.212".
          '';
        };
        filterIpProtocol = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            IP protocol filter. Provider validation is fussy here — protocol
            *names* like "udp"/"tcp"/"icmp" may be rejected by some provider
            versions; *numbers* like "17" (UDP), "6" (TCP), "1" (ICMP) work.
          '';
        };
        memoryLimit = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = ''
            Memory limit (raw integer; provider takes a number, not a "1000KiB"
            string). Units are RouterOS-side KiB. Null leaves the default.
          '';
        };
      };
    });
    default = null;
    description = ''
      RouterOS packet sniffer settings (`/tool sniffer`). It's a singleton —
      set this attribute or leave null to leave the router's existing sniffer
      config alone.
    '';
    example = lib.literalExpression ''
      {
        filterInterface = [ "wifi1" ];
        filterIpAddress = [ "185.9.72.212" ];
        filterIpProtocol = [ "17" ];  # UDP, by number
        memoryLimit = "1000KiB";
      }
    '';
  };

  config = lib.mkIf (cfg != null) {
    resource.routeros_tool_sniffer.default =
      let
        base = {
          enabled = cfg.enabled;
        }
        // lib.optionalAttrs (cfg.filterInterface != [ ]) {
          filter_interface = cfg.filterInterface;
        }
        // lib.optionalAttrs (cfg.filterIpAddress != [ ]) {
          filter_ip_address = cfg.filterIpAddress;
        }
        // lib.optionalAttrs (cfg.filterIpProtocol != [ ]) {
          filter_ip_protocol = cfg.filterIpProtocol;
        }
        // lib.optionalAttrs (cfg.memoryLimit != null) {
          memory_limit = cfg.memoryLimit;
        };
        extras = builtins.removeAttrs cfg [
          "enabled"
          "filterInterface"
          "filterIpAddress"
          "filterIpProtocol"
          "memoryLimit"
        ];
      in
      base // extras;
  };
}
