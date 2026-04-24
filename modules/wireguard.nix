{ config, lib, ... }:
let
  cfg = config.routeros.wireguard;
  helpers = config.routeros._lib;

  interfaceType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "WireGuard UDP listen port.";
      };
      mtu = lib.mkOption {
        type = lib.types.int;
        default = 1420;
        description = "MTU for the WireGuard interface.";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional comment for the interface.";
      };
    };
  };

  peerType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Resource name for this peer (must be unique within the config).";
      };
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Name of the wireguard interface this peer belongs to.";
      };
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "Peer public key (base64).";
      };
      allowedAddress = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        description = ''
          Allowed addresses for this peer. Either a comma-separated string or a list
          of CIDRs (which will be joined with commas).
        '';
      };
      endpointAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Remote endpoint address. Null for inbound-only peers.";
      };
      endpointPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Remote endpoint UDP port.";
      };
      persistentKeepalive = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Persistent keepalive interval (e.g. \"25s\").";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional comment.";
      };
      disabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable this peer without removing it.";
      };
    };
  };

  mkInterface =
    ifaceName: ifaceCfg:
    let
      base = {
        name = ifaceName;
        listen_port = ifaceCfg.listenPort;
        mtu = ifaceCfg.mtu;
      }
      // lib.optionalAttrs (ifaceCfg.comment != "") {
        comment = ifaceCfg.comment;
      };
      extras = builtins.removeAttrs ifaceCfg [
        "listenPort"
        "mtu"
        "comment"
      ];
    in
    base // extras;

  mkPeer =
    peer:
    let
      base = {
        interface = peer.interface;
        public_key = peer.publicKey;
        allowed_address =
          if builtins.isList peer.allowedAddress then
            peer.allowedAddress
          else
            lib.splitString "," peer.allowedAddress;
        disabled = peer.disabled;
      }
      // lib.optionalAttrs (peer.endpointAddress != null) {
        endpoint_address = peer.endpointAddress;
      }
      // lib.optionalAttrs (peer.endpointPort != null) {
        endpoint_port = peer.endpointPort;
      }
      // lib.optionalAttrs (peer.persistentKeepalive != null) {
        persistent_keepalive = peer.persistentKeepalive;
      }
      // lib.optionalAttrs (peer.comment != "") {
        comment = peer.comment;
      };
      extras = builtins.removeAttrs peer [
        "name"
        "interface"
        "publicKey"
        "allowedAddress"
        "endpointAddress"
        "endpointPort"
        "persistentKeepalive"
        "comment"
        "disabled"
      ];
    in
    {
      name = helpers.sanitizeName peer.name;
      value = base // extras;
    };
in
{
  options.routeros.wireguard = {
    interfaces = lib.mkOption {
      type = lib.types.attrsOf interfaceType;
      default = { };
      description = "WireGuard interfaces, keyed by interface name.";
      example = lib.literalExpression ''
        {
          wg-backbone = { listenPort = 51820; mtu = 1420; };
          wg-bulgaria = { listenPort = 55555; mtu = 1380; };
        }
      '';
    };

    peers = lib.mkOption {
      type = lib.types.listOf peerType;
      default = [ ];
      description = "WireGuard peers across all interfaces.";
      example = lib.literalExpression ''
        [
          {
            name = "moscow-backbone";
            interface = "wg-backbone";
            publicKey = "...";
            allowedAddress = [ "10.0.0.6/32" "10.0.1.0/24" ];
            endpointAddress = "94.103.92.214";
            endpointPort = 51820;
            persistentKeepalive = "25s";
            comment = "Moscow backbone (10.0.0.6)";
          }
        ]
      '';
    };
  };

  config = {
    resource = lib.mkMerge [
      (lib.mkIf (cfg.interfaces != { }) {
        routeros_interface_wireguard = lib.mapAttrs mkInterface cfg.interfaces;
      })
      (lib.mkIf (cfg.peers != [ ]) {
        routeros_interface_wireguard_peer = builtins.listToAttrs (builtins.map mkPeer cfg.peers);
      })
    ];
  };
}
