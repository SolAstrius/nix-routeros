{ config, lib, ... }:
let
  cfg = config.routeros.scripts;

  scriptType = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      source = lib.mkOption {
        type = lib.types.str;
        description = "RouterOS script source.";
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "User the script runs as.";
      };
      policy = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "ftp"
          "reboot"
          "read"
          "write"
          "policy"
          "test"
          "password"
          "sniff"
          "sensitive"
          "romon"
        ];
        description = "RouterOS permission policies.";
      };
      dontRequirePermissions = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "If true, RouterOS will not enforce that the caller has matching permissions.";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };
in
{
  options.routeros.scripts = lib.mkOption {
    type = lib.types.attrsOf scriptType;
    default = { };
    description = ''
      RouterOS scripts (`/system script`), keyed by script name. These are stored
      on the router and can be invoked manually or from a scheduler entry.
    '';
    example = lib.literalExpression ''
      {
        update-tailscale-routes = {
          owner = "sol";
          source = "''${\":resolve controlplane.tailscale.com\"}";
        };
      }
    '';
  };

  config = lib.mkIf (cfg != { }) {
    resource.routeros_system_script = lib.mapAttrs (
      scriptName: script:
      let
        base = {
          name = scriptName;
          source = script.source;
          owner = script.owner;
          policy = script.policy;
          dont_require_permissions = script.dontRequirePermissions;
        }
        // lib.optionalAttrs (script.comment != "") {
          comment = script.comment;
        };
        extras = builtins.removeAttrs script [
          "source"
          "owner"
          "policy"
          "dontRequirePermissions"
          "comment"
        ];
      in
      base // extras
    ) cfg;
  };
}
