{ config, lib, ... }:
let
  cfg = config.routeros.routes;
  helpers = config.routeros._lib;

  mkRouteResources =
    prefix: routes:
    builtins.listToAttrs (
      lib.imap0 (
        idx: route:
        let
          ruleName =
            if route ? name then helpers.sanitizeName route.name else "${prefix}_${toString idx}";
          attrs = builtins.removeAttrs route [ "name" ];
        in
        {
          name = ruleName;
          value = attrs;
        }
      ) routes
    );
in
{
  options.routeros.routes = {
    ipv4 = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = ''
        IPv4 routes. Each entry is a freeform attrset matching the routeros_ip_route
        resource schema. An optional `name` field becomes the Terraform resource id;
        otherwise auto-generated.
      '';
      example = lib.literalExpression ''
        [
          { name = "default"; dst_address = "0.0.0.0/0"; gateway = "10.0.0.254"; }
          { name = "warsaw"; dst_address = "10.0.0.1/32"; gateway = "wg-backbone"; }
        ]
      '';
    };

    ipv6 = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = ''
        IPv6 routes. Same shape as `ipv4`, but emits routeros_ipv6_route resources.
      '';
    };
  };

  config = {
    resource = lib.mkMerge [
      (lib.mkIf (cfg.ipv4 != [ ]) {
        routeros_ip_route = mkRouteResources "v4" cfg.ipv4;
      })
      (lib.mkIf (cfg.ipv6 != [ ]) {
        routeros_ipv6_route = mkRouteResources "v6" cfg.ipv6;
      })
    ];
  };
}
